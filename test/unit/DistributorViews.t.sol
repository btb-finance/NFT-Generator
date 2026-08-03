// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";
import {NFTRewardDistributor} from "../../src/NFTRewardDistributor.sol";
import {MockOPOS} from "../mocks/MockOPOS.sol";
import {MockTieredNFT} from "../mocks/MockTieredNFT.sol";

/// @notice The distributor's read surface — the numbers frontends and reaper
///         bots make decisions on — plus batch-size guards, the public sync,
///         and the try/catch around the ERC-4906 hooks.
contract DistributorViewsTest is TestBase {
    /// @dev Deterministic-tier rig: tiers are chosen, not rolled.
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

    function _ids(uint256 a) internal pure returns (uint256[] memory out) {
        out = new uint256[](1);
        out[0] = a;
    }

    function _mintTier(uint256 id, address to, uint8 tier) internal {
        mockNft.mint(_ids(id), to, tier);
    }

    // ─────────────────── constructor ───────────────────

    function test_V1_constructor_rejects_zero_addresses() public {
        vm.expectRevert(NFTRewardDistributor.ZeroAddress.selector);
        new NFTRewardDistributor(address(0), address(mockNft));

        vm.expectRevert(NFTRewardDistributor.ZeroAddress.selector);
        new NFTRewardDistributor(address(token), address(0));
    }

    function test_V1_constructor_stores_immutables() public view {
        assertEq(address(dist.REWARD_TOKEN()), address(token), "reward token");
        assertEq(address(dist.NFT()), address(mockNft), "nft");
        assertEq(dist.SLEEP_THRESHOLD(), 100 days, "sleep threshold");
        assertEq(dist.TIER_BPS() * dist.TIERS(), 10_000, "tier shares sum to 100%");
    }

    // ─────────────────── yieldMultiplier ───────────────────

    function test_V2_yieldMultiplier_rejects_out_of_range_tier() public {
        vm.expectRevert(NFTRewardDistributor.InvalidTier.selector);
        dist.yieldMultiplier(5);
    }

    function test_V2_yieldMultiplier_zero_when_either_side_empty() public {
        // No NFTs at all.
        assertEq(dist.yieldMultiplier(0), 0, "no commons => 0");

        // Commons exist but the queried tier is empty.
        _mintTier(1, actors[0], 4);
        assertEq(dist.yieldMultiplier(0), 0, "empty mythic tier => 0");

        // Mythic exists but no commons.
        MockTieredNFT nft2 = new MockTieredNFT();
        NFTRewardDistributor dist2 = new NFTRewardDistributor(address(token), address(nft2));
        nft2.setDistributor(address(dist2));
        uint256[] memory one = _ids(1);
        nft2.mint(one, actors[0], 0);
        assertEq(dist2.yieldMultiplier(0), 0, "no commons => 0");
    }

    function test_V2_yieldMultiplier_is_common_count_over_tier_count() public {
        _mintTier(1, actors[0], 0);      // 1 Mythic
        for (uint256 i = 2; i <= 66; ++i) _mintTier(i, actors[1], 4); // 65 Commons

        assertEq(dist.yieldMultiplier(0), 6500, "1 mythic vs 65 commons = 65x");
        assertEq(dist.yieldMultiplier(4), 100, "common vs common = 1x");
    }

    function test_V2_sleeping_peers_amplify_the_multiplier() public {
        _mintTier(1, actors[0], 0);
        _mintTier(2, actors[1], 0);      // 2 Mythics
        for (uint256 i = 3; i <= 12; ++i) _mintTier(i, actors[2], 4); // 10 Commons

        assertEq(dist.yieldMultiplier(0), 500, "10/2 = 5x");

        // One Mythic goes dormant — the survivor's share doubles.
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[3]);
        dist.reap(2);

        assertEq(dist.yieldMultiplier(0), 1000, "10/1 = 10x after a peer sleeps");
    }

    // ─────────────────── whole-token views ───────────────────

    function test_V3_whole_views_truncate_to_integers() public {
        _mintTier(1, actors[0], 0);
        // Tier 0's 20% of 5_000e18 goes entirely to the single Mythic.
        token.mintTo(address(dist), 5_000 ether + 5e17); // trailing 0.5 to force truncation

        uint256 pendingWei = dist.pendingReward(1);
        assertEq(dist.pendingWhole(1), pendingWei / 1e18, "pendingWhole truncates");
        assertEq(dist.lifetimeEarnedWhole(1), dist.lifetimeEarned(1) / 1e18, "lifetimeWhole truncates");
        assertEq(dist.pendingWhole(1), 1000, "1000 whole OPOS, fraction dropped");
    }

    function test_V3_lifetimeEarned_spans_claimed_plus_pending() public {
        _mintTier(1, actors[0], 4);
        token.mintTo(address(dist), 1_000 ether);

        uint256 firstPending = dist.pendingReward(1);
        assertEq(dist.lifetimeEarned(1), firstPending, "all pending before claim");

        vm.prank(actors[0]);
        dist.claim(1);
        assertEq(dist.lifetimeClaimed(1), firstPending, "moved into claimed");
        assertEq(dist.pendingReward(1), 0, "nothing left pending");
        assertEq(dist.lifetimeEarned(1), firstPending, "lifetime unchanged by claiming");

        token.mintTo(address(dist), 1_000 ether);
        assertEq(dist.lifetimeEarned(1), firstPending + dist.pendingReward(1), "claimed + new pending");
    }

    function test_V3_views_are_zero_for_unregistered_ids() public view {
        assertEq(dist.pendingReward(999), 0, "pending");
        assertEq(dist.pending(999), 0, "pending alias");
        assertEq(dist.lifetimeEarned(999), 0, "lifetime");
        assertFalse(dist.registered(999), "not registered");
        assertFalse(dist.asleep(999), "not asleep");
    }

    // ─────────────────── staleness countdown ───────────────────

    function test_V4_secondsUntilStale_counts_down_to_the_threshold() public {
        _mintTier(1, actors[0], 4);
        assertEq(dist.secondsUntilStale(1), 100 days, "full window at mint");
        assertFalse(dist.isReapable(1), "fresh mint is not reapable");

        vm.warp(block.timestamp + 40 days);
        assertEq(dist.secondsUntilStale(1), 60 days, "window shrinks with time");
        assertFalse(dist.isReapable(1), "still not reapable");

        // One second short of the threshold.
        vm.warp(block.timestamp + 60 days - 1);
        assertEq(dist.secondsUntilStale(1), 1, "one second left");
        assertFalse(dist.isReapable(1), "not reapable until the threshold lands");

        vm.warp(block.timestamp + 1);
        assertEq(dist.secondsUntilStale(1), 0, "expired");
        assertTrue(dist.isReapable(1), "reapable exactly at the threshold");

        vm.warp(block.timestamp + 365 days);
        assertEq(dist.secondsUntilStale(1), 0, "stays 0 past the threshold");
    }

    function test_V4_claiming_resets_the_countdown() public {
        _mintTier(1, actors[0], 4);
        vm.warp(block.timestamp + 99 days);
        assertEq(dist.secondsUntilStale(1), 1 days, "nearly stale");

        vm.prank(actors[0]);
        dist.claim(1); // claiming counts as activity even with nothing owed

        assertEq(dist.secondsUntilStale(1), 100 days, "window reset by claim");
        assertEq(dist.lastActivityAt(1), block.timestamp, "activity timestamp bumped");
    }

    function test_V4_sleeping_nft_reports_zero_countdown_and_not_reapable() public {
        _mintTier(1, actors[0], 4);
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        dist.reap(1);

        assertTrue(dist.asleep(1), "asleep");
        assertEq(dist.secondsUntilStale(1), 0, "asleep => 0");
        assertFalse(dist.isReapable(1), "cannot re-reap a sleeper");
        assertEq(dist.pendingReward(1), 0, "sleepers earn nothing");
    }

    function test_V4_statusBatch_reports_unregistered_ids_as_zeros() public {
        _mintTier(1, actors[0], 4);
        token.mintTo(address(dist), 1_000 ether);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 999; // never minted
        (uint256[] memory secs, uint256[] memory pend, bool[] memory sleeping) = dist.statusBatch(ids);

        assertEq(secs[0], dist.secondsUntilStale(1), "known id matches single view");
        assertEq(pend[0], dist.pendingReward(1), "known id pending matches");
        assertFalse(sleeping[0], "known id awake");

        // Unregistered ids have lastActivityAt == 0, so their countdown is
        // measured from the epoch — it means nothing, but it must not revert.
        assertEq(secs[1], 100 days - block.timestamp, "unregistered counts down from epoch");
        assertEq(pend[1], 0, "unregistered pays nothing");
        assertFalse(sleeping[1], "unregistered is not asleep");
    }

    function test_V4_statusBatch_handles_empty_input() public view {
        uint256[] memory none = new uint256[](0);
        (uint256[] memory secs, uint256[] memory pend, bool[] memory sleeping) = dist.statusBatch(none);
        assertEq(secs.length, 0, "empty");
        assertEq(pend.length, 0, "empty");
        assertEq(sleeping.length, 0, "empty");
    }

    // ─────────────────── public sync ───────────────────

    function test_V5_anyone_can_sync_and_it_is_idempotent() public {
        _mintTier(1, actors[0], 4);
        token.mintTo(address(dist), 1_000 ether);

        vm.prank(actors[3]); // a random address, not the owner or a holder
        dist.sync();

        assertEq(dist.lastBalance(), 1_000 ether, "balance booked");
        uint256 accAfter = dist.accRewardPerSlot(4);

        // A second sync with no new fees must not move the index.
        vm.prank(actors[3]);
        dist.sync();
        assertEq(dist.accRewardPerSlot(4), accAfter, "no double-count");
        assertEq(dist.lastBalance(), 1_000 ether, "balance unchanged");
    }

    function test_V5_sync_parks_share_of_empty_tiers_in_tierPending() public {
        _mintTier(1, actors[0], 4); // Commons only
        token.mintTo(address(dist), 1_000 ether);
        dist.sync();

        assertEq(dist.tierPending(4), 0, "occupied tier accrues directly");
        for (uint8 t = 0; t < 4; ++t) {
            assertEq(dist.tierPending(t), 200 ether, "empty tier parks its 20%");
        }

        // The first mint into an empty tier collects that whole backlog.
        _mintTier(2, actors[1], 0);
        assertEq(dist.tierPending(0), 0, "backlog released");
        assertEq(dist.pendingReward(2), 200 ether, "first Mythic inherits the backlog");
    }

    // ─────────────────── batch guards ───────────────────

    function test_V6_claimMany_rejects_empty_and_oversized_batches() public {
        _mintTier(1, actors[0], 4);

        uint256[] memory none = new uint256[](0);
        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.EmptyBatch.selector);
        dist.claimMany(none);

        uint256[] memory tooMany = new uint256[](dist.MAX_CLAIM_BATCH() + 1);
        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.BatchTooLarge.selector);
        dist.claimMany(tooMany);
    }

    function test_V6_wakeMany_rejects_empty_and_oversized_batches() public {
        uint256[] memory none = new uint256[](0);
        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.EmptyBatch.selector);
        dist.wakeMany(none);

        uint256[] memory tooMany = new uint256[](dist.MAX_CLAIM_BATCH() + 1);
        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.BatchTooLarge.selector);
        dist.wakeMany(tooMany);
    }

    function test_V6_max_batch_size_is_accepted() public {
        uint256 max = dist.MAX_CLAIM_BATCH();
        uint256[] memory ids = new uint256[](max);
        for (uint256 i; i < max; ++i) ids[i] = i + 1;
        mockNft.mint(ids, actors[0], 4);
        token.mintTo(address(dist), 1_000 ether);

        uint256 before = token.balanceOf(actors[0]);
        vm.prank(actors[0]);
        dist.claimMany(ids); // exactly at the cap — must not revert

        assertEq(token.balanceOf(actors[0]) - before, 200 ether, "whole Common share paid out");
    }

    function test_V6_facade_entrypoints_reject_non_NFT_callers() public {
        uint256[] memory ids = _ids(1);
        _mintTier(1, actors[0], 4);

        vm.startPrank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.NotNFT.selector);
        dist.claimFor(actors[0], 1);

        vm.expectRevert(NFTRewardDistributor.NotNFT.selector);
        dist.claimManyFor(actors[0], ids);

        vm.expectRevert(NFTRewardDistributor.NotNFT.selector);
        dist.wakeFor(actors[0], 1);

        vm.expectRevert(NFTRewardDistributor.NotNFT.selector);
        dist.wakeManyFor(actors[0], ids);
        vm.stopPrank();
    }

    // ─────────────────── ERC-4906 hook resilience ───────────────────

    function test_V7_claim_survives_a_reverting_metadata_hook() public {
        _mintTier(1, actors[0], 4);
        token.mintTo(address(dist), 1_000 ether);
        mockNft.setHooksRevert(true);

        uint256 before = token.balanceOf(actors[0]);
        vm.expectEmit(address(dist));
        emit NFTRewardDistributor.MetadataUpdateFailed(1);
        vm.prank(actors[0]);
        dist.claim(1);

        // The payout is what matters; a broken refresh signal must not block it.
        assertEq(token.balanceOf(actors[0]) - before, 200 ether, "still paid");
        assertEq(dist.lifetimeClaimed(1), 200 ether, "still booked");
    }

    function test_V7_batch_claim_survives_a_reverting_metadata_hook() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        mockNft.mint(ids, actors[0], 4);
        token.mintTo(address(dist), 1_000 ether);
        mockNft.setHooksRevert(true);

        vm.expectEmit(address(dist));
        emit NFTRewardDistributor.BatchMetadataUpdateFailed();
        vm.prank(actors[0]);
        dist.claimMany(ids);

        assertEq(token.balanceOf(actors[0]), 200 ether, "both tokens paid");
    }

    function test_V7_reap_and_wake_survive_a_reverting_metadata_hook() public {
        _mintTier(1, actors[0], 4);
        token.mintTo(address(dist), 1_000 ether);
        mockNft.setHooksRevert(true);
        vm.warp(block.timestamp + 100 days);

        vm.prank(actors[1]);
        dist.reap(1);
        assertTrue(dist.asleep(1), "reap still went through");
        assertEq(token.balanceOf(actors[1]), 200 ether, "reaper still paid");

        vm.prank(actors[0]);
        dist.wake(1);
        assertFalse(dist.asleep(1), "wake still went through");
    }
}
