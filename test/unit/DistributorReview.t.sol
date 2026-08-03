// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";
import {console} from "forge-std/console.sol";
import {NFTRewardDistributor} from "../../src/NFTRewardDistributor.sol";
import {MockTieredNFT} from "../mocks/MockTieredNFT.sol";
import {MockOPOS} from "../mocks/MockOPOS.sol";
import {SyncReenterToken} from "../mocks/SyncReenterToken.sol";

/// @notice Findings from reviewing NFTRewardDistributor. Each test either
///         proves a concern is unfounded or pins the real behaviour so it is
///         documented rather than discovered in production.
///
///         Context that makes these worth writing down: the distributor has no
///         owner, no pause, no upgrade path and no rescue function, and
///         OposNFT.setDistributor locks permanently at the first mint. Nothing
///         found here can be patched after launch.
contract DistributorReviewTest is TestBase {
    MockTieredNFT internal mockNft;
    NFTRewardDistributor internal dist;
    MockOPOS internal token;

    function setUp() public override {
        super.setUp();
        token = new MockOPOS();
        mockNft = new MockTieredNFT();
        dist = new NFTRewardDistributor(address(token), address(mockNft));
        mockNft.setDistributor(address(dist));
    }

    function _mintTier(uint256 id, address to, uint8 tier) internal {
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        mockNft.mint(ids, to, tier);
    }

    // ─────────────────────────────────────────────────────────────
    // FINDING 1 — `sync()` is the only state-changing function without
    // `nonReentrant`. Does that matter?
    // ─────────────────────────────────────────────────────────────

    function test_R1_reentrant_sync_during_payout_cannot_corrupt_accounting() public {
        SyncReenterToken evil = new SyncReenterToken();
        MockTieredNFT nft2 = new MockTieredNFT();
        NFTRewardDistributor dist2 = new NFTRewardDistributor(address(evil), address(nft2));
        nft2.setDistributor(address(dist2));

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        nft2.mint(ids, actors[0], 4);

        evil.mintTo(address(dist2), 1_000 ether);
        evil.arm(address(dist2)); // re-enter sync() mid-payout

        // With sync() guarded the re-entry reverts, which reverts the whole
        // claim. Failing closed is the correct outcome: the alternative is
        // silently corrupted books that no one can repair.
        vm.prank(actors[0]);
        vm.expectRevert();
        dist2.claim(1);

        // The books must never claim more than the contract actually holds:
        // lastBalance above the real balance means later claims revert forever
        // and the remaining rewards are stranded, with no admin able to fix it.
        assertLe(
            dist2.lastBalance(),
            evil.balanceOf(address(dist2)),
            "lastBalance drifted above the real balance"
        );

        console.log("after reentrant sync - lastBalance:", dist2.lastBalance());
        console.log("after reentrant sync - real balance:", evil.balanceOf(address(dist2)));
    }

    // ─────────────────────────────────────────────────────────────
    // FINDING 2 — waking several NFTs of an empty tier in one call. The
    // backlog release is written to give the whole banked amount to the FIRST
    // token woken, whereas onMintBatch splits it across the batch.
    // ─────────────────────────────────────────────────────────────

    function test_R2_batch_wake_gives_the_whole_backlog_to_the_first_token() public {
        _mintTier(1, actors[0], 0);
        _mintTier(2, actors[0], 0); // two Mythics, same owner

        // Both go stale and are reaped, emptying the tier.
        vm.warp(block.timestamp + 100 days);
        vm.startPrank(actors[1]);
        dist.reap(1);
        dist.reap(2);
        vm.stopPrank();
        assertEq(dist.activeInTier(0), 0, "tier is empty");

        // Fees arrive with nobody in the tier: they bank in tierPending.
        token.mintTo(address(dist), 1_000 ether);
        dist.sync();
        assertEq(dist.tierPending(0), 200 ether, "tier 0 banked its 20%");

        // Owner wakes both in one call.
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        vm.prank(actors[0]);
        dist.wakeMany(ids);

        uint256 first = dist.pendingReward(1);
        uint256 second = dist.pendingReward(2);
        console.log("first token woken  ->", first);
        console.log("second token woken ->", second);

        // Documented behaviour: first taker gets everything.
        assertEq(first, 200 ether, "first token takes the entire backlog");
        assertEq(second, 0, "second token gets nothing");

        // Contrast: minting two fresh tokens into an empty tier SPLITS the
        // backlog between them. Same situation, opposite rule.
        _mintTier(3, actors[2], 1);
        token.mintTo(address(dist), 1_000 ether);
        dist.sync();
        uint256 banked = dist.tierPending(2);
        assertGt(banked, 0, "tier 2 has a backlog");

        uint256[] memory pair = new uint256[](2);
        pair[0] = 10;
        pair[1] = 11;
        mockNft.mint(pair, actors[2], 2);
        assertEq(dist.pendingReward(10), dist.pendingReward(11), "mint splits the backlog evenly");
        assertGt(dist.pendingReward(10), 0, "and both actually receive some");
    }

    // ─────────────────────────────────────────────────────────────
    // FINDING 3 — isReapable() answers for ids that were never minted.
    // ─────────────────────────────────────────────────────────────

    function test_R3_isReapable_is_true_for_ids_that_do_not_exist() public {
        // lastActivityAt defaults to 0, so any unminted id looks stale once
        // 100 days have passed since the epoch — which is always, on mainnet.
        vm.warp(block.timestamp + 100 days);

        assertTrue(dist.isReapable(999_999), "unminted id reports reapable");
        assertFalse(dist.registered(999_999), "...but it was never registered");

        // reap() itself is safe; the cost is bots burning gas on ids that can
        // never succeed.
        vm.expectRevert(NFTRewardDistributor.NotRegistered.selector);
        dist.reap(999_999);
    }

    // ─────────────────────────────────────────────────────────────
    // FINDING 4 — a holder can reap their own NFT. Worth pinning: it is a
    // cheaper "claim everything and stop earning" than claim() plus waiting.
    // ─────────────────────────────────────────────────────────────

    function test_R4_self_reap_is_equivalent_to_claiming_then_sleeping() public {
        _mintTier(1, actors[0], 4);
        token.mintTo(address(dist), 1_000 ether);
        vm.warp(block.timestamp + 100 days);

        uint256 before = token.balanceOf(actors[0]);
        vm.prank(actors[0]);
        dist.reap(1); // owner reaps their own token

        assertEq(token.balanceOf(actors[0]) - before, 200 ether, "owner keeps the full amount");
        assertTrue(dist.asleep(1), "and the NFT goes to sleep");
        // Nothing is lost, but the NFT stops earning until wake() is called.
    }

    // ─────────────────────────────────────────────────────────────
    // FINDING 5 — the thing that makes all of the above matter.
    // ─────────────────────────────────────────────────────────────

    function test_R5_distributor_is_permanently_unfixable_after_first_mint() public {
        // Wiring is one-shot: OposNFT refuses to re-point once minting starts.
        _buyAs(actors[0], 1);
        vm.prank(owner);
        vm.expectRevert("Cannot change distributor after minting begins");
        nft.setDistributor(address(dist));

        // And the distributor itself has no owner, no pause and no rescue, so
        // there is no second lever either. Any reward tokens it holds are
        // reachable only through claim/reap by NFT holders.
        assertGt(address(distributor).code.length, 0, "distributor is deployed");
    }
}
