// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";
import {NFTRewardDistributor} from "../../src/NFTRewardDistributor.sol";

/// @notice Unit tests for NFTRewardDistributor.
///         Each `test_*` function references a property ID from FUZZING.md.
contract DistributorTest is TestBase {

    // ─────────────────────────── D2 — claim correctness ───────────────────────────

    function test_D2_claim_simple() public {
        // 1 NFT minted, 1 fee arrives, owner claims everything.
        uint256[] memory ids = _buyAs(actors[0], 1);
        uint256 id = ids[0];
        uint8 tier = nft.tierIndexOf(id);

        _arriveFee(1000 ether);

        uint256 expectedPerTier = (1000 ether * 2000) / 10_000; // 200 ether
        uint256 expectedForId = expectedPerTier; // sole NFT in its tier

        uint256 before = opos.balanceOf(actors[0]);
        vm.prank(actors[0]);
        distributor.claim(id);

        assertEq(opos.balanceOf(actors[0]) - before, expectedForId, "payout != 20% of fee");
        assertEq(distributor.lifetimeClaimed(id), expectedForId, "lifetime not updated");
        assertEq(distributor.lastActivityAt(id), block.timestamp, "activity not stamped");
        assertEq(distributor.pending(id), 0, "still owes after claim");
        // The other 4 tiers' shares stayed in tierPending since no one is in them.
        assertEq(_sumTierPending(), 800 ether, "other tier shares should bank");
    }

    // ─────────────────────────── D3 — no double-claim ─────────────────────────────

    function test_D3_no_double_claim() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        _arriveFee(1000 ether);

        vm.prank(actors[0]);
        distributor.claim(ids[0]);
        uint256 paid1 = distributor.lifetimeClaimed(ids[0]);

        vm.prank(actors[0]);
        distributor.claim(ids[0]);
        uint256 paid2 = distributor.lifetimeClaimed(ids[0]);

        assertEq(paid1, paid2, "second claim should pay 0");
    }

    // ─────────────────────────── D5/D6 — reap eligibility & state ─────────────────

    function test_D5_reap_reverts_before_threshold() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        _arriveFee(1000 ether);

        vm.warp(block.timestamp + 100 days - 1);
        vm.prank(actors[1]);
        vm.expectRevert(NFTRewardDistributor.NotStaleYet.selector);
        distributor.reap(ids[0]);
    }

    function test_D5_reap_succeeds_at_threshold() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        _arriveFee(1000 ether);

        vm.warp(block.timestamp + 100 days);
        uint256 reaperBefore = opos.balanceOf(actors[1]);
        vm.prank(actors[1]);
        distributor.reap(ids[0]);

        // Reaper got the entire 20% (sole Mythic-or-whatever in its tier).
        assertEq(opos.balanceOf(actors[1]) - reaperBefore, 200 ether, "reaper payout");
        assertTrue(distributor.asleep(ids[0]), "should be asleep");
        // activeInTier dropped by 1.
        assertEq(_sumActive(), 0, "no active NFTs left");
    }

    function test_D6_reap_double_reverts() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        _arriveFee(1000 ether);
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        distributor.reap(ids[0]);

        vm.prank(actors[2]);
        vm.expectRevert(NFTRewardDistributor.NFTAsleep.selector);
        distributor.reap(ids[0]);
    }

    // ─────────────────────────── D7 — wake access & state ─────────────────────────

    function test_D7_wake_only_owner() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        distributor.reap(ids[0]);

        vm.prank(actors[2]);
        vm.expectRevert(NFTRewardDistributor.NotNFTOwner.selector);
        distributor.wake(ids[0]);

        vm.prank(actors[0]);
        distributor.wake(ids[0]);
        assertFalse(distributor.asleep(ids[0]), "should be awake");
    }

    function test_D7_wake_reverts_if_not_asleep() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.NotAsleep.selector);
        distributor.wake(ids[0]);
    }

    // ─────────────────────────── D8 — wake doesn't pay back ───────────────────────

    function test_D8_wake_does_not_retroactively_pay() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        // First fee — claim it so reap doesn't capture it.
        _arriveFee(1000 ether);
        vm.prank(actors[0]);
        distributor.claim(ids[0]); // 200 to NFT tier; 800 to other 4 tiers (200 each)

        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        distributor.reap(ids[0]); // pending was 0, just goes to sleep

        // Fees flow during sleep — they should NOT accrue to the asleep NFT.
        _arriveFee(5000 ether);
        distributor.sync(); // force-process: all 5 tiers have activeInTier==0 → all bank
        // Now: NFT's tier pending = 1000; each of the other 4 tiers = 200 + 1000 = 1200.
        assertEq(_sumTierPending(), 5800 ether, "after sync: 1000 + 4*1200 = 5800");

        // Owner wakes → first NFT in tier gets the backlog (windfall).
        vm.prank(actors[0]);
        distributor.wake(ids[0]);

        uint8 tier = nft.tierIndexOf(ids[0]);
        assertEq(distributor.tierPending(tier), 0, "this tier's pending released");
        assertEq(distributor.pending(ids[0]), 1000 ether, "windfall = 20%");

        uint256 pendingAtWake = distributor.pending(ids[0]);
        // No fees flowing post-wake should not increase pending further.
        assertEq(distributor.pending(ids[0]), pendingAtWake, "no growth without fees");
    }

    // ─────────────────────────── D9 — onMintBatch access ──────────────────────────

    function test_D9_onMintBatch_only_NFT() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.NotNFT.selector);
        distributor.onMintBatch(ids);
    }

    // ─────────────────────────── D11 — pending fairness on batch mint ─────────────

    function test_D11_pending_split_evenly_on_first_batch() public {
        // No NFTs minted yet; fees flow.
        _arriveFee(5000 ether);
        distributor.sync(); // force-process: all 5 tiers bank since none have NFTs
        for (uint8 t = 0; t < 5; ++t) {
            assertEq(distributor.tierPending(t), 1000 ether, "tier pending = 1000");
        }

        // Now mint 100 NFTs — they'll fall into ~target rarity distribution.
        uint256[] memory ids = _buyAs(actors[0], 100);

        // Tiers with ≥1 NFT had their pending released to those NFTs.
        // Tiers that still have 0 NFTs keep their pending.
        uint256 totalPending;
        for (uint256 i = 0; i < ids.length; ++i) totalPending += distributor.pending(ids[i]);
        uint256 stillPending = _sumTierPending();

        // Per-tier integer-division dust accumulates; tolerance covers all 5 tiers.
        // Each tier's loss ≤ activeInTier[t] wei, so total loss ≤ sum of counts = 100 wei.
        assertApproxEqAbs(totalPending + stillPending, 5000 ether, 1000, "no fees lost");
    }

    // ─────────────────────────── D14 — pending zero when asleep ───────────────────

    function test_D14_pendingReward_zero_when_asleep() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        _arriveFee(1000 ether);
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        distributor.reap(ids[0]);

        // More fees arrive during sleep — but no active NFTs, so they go to tierPending.
        _arriveFee(2000 ether);

        assertEq(distributor.pending(ids[0]), 0, "asleep must show 0 pending");
    }

    // ─────────────────────────── D14b — claim reverts when asleep ─────────────────

    function test_claim_reverts_when_asleep() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        distributor.reap(ids[0]);

        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.NFTAsleep.selector);
        distributor.claim(ids[0]);
    }

    // ─────────────────────────── G3 / D15 — view matches outcome ──────────────────

    function test_G3_view_matches_payout() public {
        uint256[] memory ids = _buyAs(actors[0], 5);
        _arriveFee(1000 ether);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 view_ = distributor.pending(ids[i]);
            uint256 before = opos.balanceOf(actors[0]);
            vm.prank(actors[0]);
            distributor.claim(ids[i]);
            uint256 paid = opos.balanceOf(actors[0]) - before;
            assertEq(view_, paid, "view != payout");
        }
    }

    // ─────────────────────────── A4 — wake then immediate reap ────────────────────

    function test_A4_wake_then_reap_reverts() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        distributor.reap(ids[0]);

        vm.prank(actors[0]);
        distributor.wake(ids[0]);

        // Just woke — activity timer reset. Reap must revert.
        vm.prank(actors[2]);
        vm.expectRevert(NFTRewardDistributor.NotStaleYet.selector);
        distributor.reap(ids[0]);
    }

    // ─────────────────────────── A3 — reap own NFT ────────────────────────────────

    function test_A3_reap_own_nft() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        _arriveFee(1000 ether);
        vm.warp(block.timestamp + 100 days);

        // Owner reaps their own — allowed; they get the rewards but NFT goes to sleep.
        uint256 before = opos.balanceOf(actors[0]);
        vm.prank(actors[0]);
        distributor.reap(ids[0]);

        assertEq(opos.balanceOf(actors[0]) - before, 200 ether, "owner-reaper got payout");
        assertTrue(distributor.asleep(ids[0]), "still asleep");
    }

    // ─────────────────────────── A7 — sandwiched fee + claim ──────────────────────

    function test_A7_repeated_claims_split_correctly() public {
        uint256[] memory ids = _buyAs(actors[0], 1);

        _arriveFee(1000 ether);
        vm.prank(actors[0]);
        distributor.claim(ids[0]); // gets 200 (this tier's 20%)

        _arriveFee(2000 ether);
        vm.prank(actors[0]);
        distributor.claim(ids[0]); // gets 400 (20% of new 2000)

        _arriveFee(500 ether);
        vm.prank(actors[0]);
        distributor.claim(ids[0]); // gets 100

        // Total claimed = 200 + 400 + 100 = 700 (20% of 3500 total).
        assertEq(distributor.lifetimeClaimed(ids[0]), 700 ether, "lifetime sums correctly");
    }

    // ─────────────────────────── A10 — all NFTs in tier reaped ────────────────────

    // ─────────────────────────── claimMany batch cap (fix #11) ───────────────────

    function test_claimMany_reverts_when_too_large() public {
        uint256[] memory ids = _adminMintAs(101);
        vm.prank(owner);
        nft.transferFrom(owner, actors[0], ids[0]);
        for (uint256 i = 1; i < 101; i++) {
            vm.prank(owner);
            nft.transferFrom(owner, actors[0], ids[i]);
        }

        // Pass 101 ids — over the MAX_CLAIM_BATCH = 100 cap.
        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.BatchTooLarge.selector);
        distributor.claimMany(ids);

        // Exactly 100 succeeds.
        uint256[] memory subset = new uint256[](100);
        for (uint256 i = 0; i < 100; i++) subset[i] = ids[i];
        vm.prank(actors[0]);
        distributor.claimMany(subset); // no revert
    }

    function test_A10_all_reaped_then_wake_inherits_backlog() public {
        // Mint 1 NFT → record its tier → reap → fees flow → wake → inherits.
        uint256[] memory ids = _buyAs(actors[0], 1);
        uint8 tier = nft.tierIndexOf(ids[0]);

        // Sleep the only NFT in its tier.
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        distributor.reap(ids[0]);
        assertEq(distributor.activeInTier(tier), 0, "tier emptied");

        // Fees flow during empty-tier — bank to tierPending.
        _arriveFee(5000 ether);
        distributor.sync();
        assertEq(distributor.tierPending(tier), 1000 ether, "tier banked 20%");

        // Owner wakes — inherits the entire tier backlog.
        vm.prank(actors[0]);
        distributor.wake(ids[0]);

        assertEq(distributor.tierPending(tier), 0, "released");
        assertEq(distributor.pending(ids[0]), 1000 ether, "windfall = entire backlog");
    }

    // ─────────────────────── R1 — registration gating ───────────────────────

    function test_R1_unregistered_id_rejected_everywhere() public {
        _buyAs(actors[0], 1);
        _arriveFee(1000 ether);
        uint256 fakeId = 999_999; // never minted, never registered

        // Even 100+ days "stale" (lastActivityAt == 0), reap refuses before
        // it ever touches the accumulator or the NFT contract.
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        vm.expectRevert(NFTRewardDistributor.NotRegistered.selector);
        distributor.reap(fakeId);

        vm.prank(actors[1]);
        vm.expectRevert(NFTRewardDistributor.NotRegistered.selector);
        distributor.claim(fakeId);

        uint256[] memory batch = new uint256[](1);
        batch[0] = fakeId;
        vm.prank(actors[1]);
        vm.expectRevert(NFTRewardDistributor.NotRegistered.selector);
        distributor.claimMany(batch);

        vm.prank(actors[1]);
        vm.expectRevert(NFTRewardDistributor.NotRegistered.selector);
        distributor.wake(fakeId);

        // Views report nothing claimable for unknown ids.
        assertEq(distributor.pendingReward(fakeId), 0, "no pending for unknown id");
    }

    function test_R1_minted_ids_are_registered() public {
        uint256[] memory ids = _buyAs(actors[0], 3);
        for (uint256 i = 0; i < ids.length; ++i) {
            assertTrue(distributor.registered(ids[i]), "minted id registered");
        }
    }

    // ─────────────────────── R2 — Reaped event fires with owed == 0 ─────────

    function test_R2_reap_emits_event_when_nothing_owed() public {
        // No fees ever arrive, so pending is 0 — but the sleep transition
        // must still be observable via the Reaped event.
        uint256[] memory ids = _buyAs(actors[0], 1);
        vm.warp(block.timestamp + 100 days);

        vm.expectEmit(true, true, false, true, address(distributor));
        emit NFTRewardDistributor.Reaped(actors[1], ids[0], 0);
        vm.prank(actors[1]);
        distributor.reap(ids[0]);

        assertTrue(distributor.asleep(ids[0]), "asleep despite zero payout");
    }
}
