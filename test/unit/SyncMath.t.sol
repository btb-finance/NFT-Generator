// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";

/// @notice Hard-edged tests for the `_sync` math + the projected-vs-synced
///         reconciliation. If "scan is wrong" is what you fear, these tests
///         are designed to catch it: they verify that after any sequence of
///         fees + partial claims, the books balance exactly.
contract SyncMathTest is TestBase {

    // ─────────────────────── D15 — projection matches sync ─────────────────────

    /// @notice For any state, `pending(id)` (which projects un-synced fees) must
    ///         equal what the user actually receives if they claim. View math
    ///         and mutating math must agree.
    function test_D15_projected_pending_equals_payout() public {
        uint256[] memory ids = _adminMintAs(20);

        // Phase 1: fee, no sync, then check projection vs claim payout.
        _arriveFee(1234 ether);
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 view_ = distributor.pending(ids[i]);
            uint256 before = opos.balanceOf(actors[0]);
            // Transfer the NFT to actor 0 first so they can claim.
            address holder = nft.ownerOf(ids[i]);
            if (view_ == 0) continue;
            vm.prank(holder);
            nft.transferFrom(holder, actors[0], ids[i]);
            vm.prank(actors[0]);
            distributor.claim(ids[i]);
            uint256 paid = opos.balanceOf(actors[0]) - before;
            assertEq(view_, paid, "projection != actual payout");
        }
    }

    // ─────────────────────── multi-actor conservation ──────────────────────────

    /// @notice Run a chaotic but controlled sequence:
    ///         - Multiple users mint
    ///         - Multiple fees arrive (different sizes)
    ///         - Random claim ordering
    ///         - Final assertion: paid_total + balance_remaining == fees_received
    function test_multi_actor_books_balance() public {
        // Actors 0..4 each get 4 NFTs via gift.
        address[] memory recipients = new address[](20);
        for (uint256 i = 0; i < 20; ++i) recipients[i] = actors[i % 5];
        vm.prank(owner);
        nft.giftNFT(recipients);

        // Five irregular fee waves.
        uint256[5] memory fees = [
            uint256(1234567 ether),
            999 ether,
            42 ether,
            7777 ether,
            1 wei // adversarial tiny fee — most lost as dust per `_sync` after BPS split
        ];
        uint256 totalFees;
        for (uint256 i = 0; i < fees.length; ++i) {
            _arriveFee(fees[i]);
            totalFees += fees[i];
            // Some claims interleaved.
            if (i % 2 == 0) {
                _claimAllFor(actors[i % 5]);
            }
        }
        // Final round of claims.
        for (uint256 i = 0; i < 5; ++i) _claimAllFor(actors[i]);
        distributor.sync(); // bring lastBalance current

        // Sum lifetime claimed across all NFTs.
        uint256 totalPaid;
        uint256 maxId = nft.totalSupply();
        for (uint256 id = 1; id <= maxId; ++id) {
            totalPaid += distributor.lifetimeClaimed(id);
        }
        uint256 distBalance = opos.balanceOf(address(distributor));

        // The headline conservation: every wei of fees is either paid out or
        // sitting in the contract. No invention, no loss.
        assertEq(totalPaid + distBalance, totalFees, "books don't balance");
    }

    // ─────────────────────── tiny-fee dust accounting ──────────────────────────

    /// @notice A 1-wei fee can't split 5 ways evenly. The whole wei stays in
    ///         the contract as dust. Conservation must still hold.
    function test_one_wei_fee_is_dust() public {
        uint256[] memory ids = _adminMintAs(10);
        ids;

        _arriveFee(1 wei);
        distributor.sync();

        // 1 wei × 20% / 10000 = 0 wei share per tier. Nothing goes to indices.
        // tierPending may or may not be 0 depending on activeInTier per tier.
        // Either way: balance is 1 wei, totalPaid is 0, fees received is 1.
        assertEq(opos.balanceOf(address(distributor)), 1 wei, "1 wei stuck");
    }

    // ─────────────────────── reap doesn't leak fees ────────────────────────────

    function test_reap_then_claim_then_reap_conservation() public {
        uint256[] memory ids = _buyAs(actors[0], 3);

        _arriveFee(10_000 ether);
        // Owner claims 1 of 3.
        vm.prank(actors[0]);
        distributor.claim(ids[0]);

        // Time passes. Owner forgot the other 2.
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]); distributor.reap(ids[1]);
        vm.prank(actors[2]); distributor.reap(ids[2]);

        // More fees, owner wakes #1 (still active) and #2 (asleep).
        // Wait — #0 is the one not asleep. Re-check: ids[0] was claimed, so it
        // had its activity timestamp reset 100 days ago. After the +100 days
        // warp, ids[0] is now stale too. But it's not asleep yet.
        // Anyone can reap ids[0] now.
        vm.prank(actors[3]); distributor.reap(ids[0]);

        // All 3 NFTs are asleep. Final fee.
        _arriveFee(5000 ether);
        distributor.sync();

        // Conservation: paid + dist balance == 15000 ether.
        uint256 paid;
        for (uint256 i = 0; i < ids.length; ++i) {
            paid += distributor.lifetimeClaimed(ids[i]);
        }
        uint256 distBalance = opos.balanceOf(address(distributor));
        assertEq(paid + distBalance, 15_000 ether, "books balance after reap chain");
    }

    // ─────────────────────── helper ────────────────────────────────────────────

    function _claimAllFor(address actor) internal {
        uint256 maxId = nft.totalSupply();
        uint256[] memory owned = new uint256[](maxId);
        uint256 count;
        for (uint256 id = 1; id <= maxId; ++id) {
            try this.ownerOfTry(id) returns (address o) {
                if (o == actor && !distributor.asleep(id)) {
                    owned[count++] = id;
                }
            } catch {}
        }
        if (count == 0) return;
        uint256[] memory list = new uint256[](count);
        for (uint256 i = 0; i < count; ++i) list[i] = owned[i];
        vm.prank(actor);
        try distributor.claimMany(list) {} catch {}
    }

    function ownerOfTry(uint256 id) external view returns (address) {
        return nft.ownerOf(id);
    }

    /// @notice "A fee arrives just before I claim — do I miss it?" — No.
    ///         The claim path calls `_sync()` first, which rolls in ALL drifts
    ///         (including fees that arrived in the same block, in earlier txs).
    ///         The user's payout includes the just-arrived share.
    function test_fee_just_before_claim_is_included() public {
        uint256[] memory ids = _buyAs(actors[0], 1);

        // Round 1: 100 OPOS, sync. NFT has 20 OPOS pending (sole NFT in its tier).
        _arriveFee(100 ether);
        distributor.sync();
        assertEq(distributor.pending(ids[0]), 20 ether, "20 already pending");
        assertEq(distributor.lastBalance(), 100 ether, "lastBalance synced");

        // Round 2: 1 OPOS arrives. NO explicit sync — we're testing that claim
        // catches it.
        _arriveFee(1 ether);
        assertEq(opos.balanceOf(address(distributor)), 101 ether, "balance grew");
        assertEq(distributor.lastBalance(), 100 ether, "lastBalance NOT yet updated");

        // Even before sync, the view picks up the new fee via projection.
        // 1 OPOS × 20% / 1 NFT = 0.2 added → 20.2 total.
        assertEq(distributor.pending(ids[0]), 20.2 ether, "view sees the new fee");

        // ─ Claim ─
        uint256 before = opos.balanceOf(actors[0]);
        vm.prank(actors[0]);
        nft.claim(ids[0]);
        uint256 paid = opos.balanceOf(actors[0]) - before;

        assertEq(paid, 20.2 ether, "got both old (20) AND new (0.2)");

        // After claim, lastBalance reflects the new total minus payout.
        // 100 + 1 − 20.2 = 80.8
        assertEq(distributor.lastBalance(), 80.8 ether, "lastBalance synced post-claim");
        assertEq(opos.balanceOf(address(distributor)), 80.8 ether, "actual balance matches");

        // The 0.8 remaining represents the 4 other tiers' 20% shares of the 1 OPOS
        // that banked in tierPending (no NFTs in those tiers).
        assertEq(_sumTierPending(), 80 ether + 0.8 ether, "other tiers still hold their cut");
    }

    /// @notice The "balance returns to the same number" worry: claim drops the
    ///         balance, then a new fee restores it to the original number. A
    ///         naive implementation would think nothing happened. We don't
    ///         implement it that way — `lastBalance` is decremented during the
    ///         claim, so the new fee is still correctly seen as new.
    function test_balance_returns_to_same_number_still_detects_new_fee() public {
        uint256[] memory ids = _buyAs(actors[0], 1);

        // Round 1: 100 OPOS arrives. After sync, NFT has 20 OPOS pending
        // (it's the only one in its tier, so it gets the full tier share).
        _arriveFee(100 ether);
        distributor.sync();
        uint256 distBalanceA = opos.balanceOf(address(distributor));
        uint256 lastBalanceA = distributor.lastBalance();
        assertEq(distBalanceA, 100 ether, "step A: 100 in contract");
        assertEq(lastBalanceA, 100 ether, "step A: lastBalance = 100");
        assertEq(distributor.pending(ids[0]), 20 ether, "step A: 20 pending (sole NFT in tier)");

        // ─ NFT owner claims 20 OPOS ─
        vm.prank(actors[0]);
        nft.claim(ids[0]);
        uint256 distBalanceB = opos.balanceOf(address(distributor));
        uint256 lastBalanceB = distributor.lastBalance();
        assertEq(distBalanceB, 80 ether, "step B: 80 in contract");
        assertEq(lastBalanceB, 80 ether, "step B: lastBalance = 80 (decremented in claim)");
        assertEq(distributor.pending(ids[0]), 0, "step B: pending zeroed");

        // ─ Now a new 20 OPOS fee arrives — balance goes from 80 back to 100 ─
        _arriveFee(20 ether);
        uint256 distBalanceC = opos.balanceOf(address(distributor));
        uint256 lastBalanceC = distributor.lastBalance();
        assertEq(distBalanceC, 100 ether, "step C: balance is 100 again (same as step A!)");
        assertEq(lastBalanceC, 80 ether, "step C: lastBalance still 80 (no sync yet)");

        // Even though balance == 100 (same number as step A), the contract
        // sees the diff = 100 - 80 = 20, NOT zero. The new fee is correctly
        // recognized as new because lastBalance is the source of truth, not
        // the absolute balance number.
        uint256 expectedNewPending = (20 ether * 2000) / 10000; // 20% of new fee, 1 NFT in tier
        assertEq(distributor.pending(ids[0]), expectedNewPending, "step C: new fee detected");

        // Claim the new fee.
        vm.prank(actors[0]);
        nft.claim(ids[0]);
        uint256 distBalanceD = opos.balanceOf(address(distributor));
        uint256 lastBalanceD = distributor.lastBalance();
        assertEq(distBalanceD, 96 ether, "step D: 100 - 4 = 96");
        assertEq(lastBalanceD, 96 ether, "step D: lastBalance synced");

        // Conservation: total received = lifetimeClaimed + balance.
        assertEq(
            distributor.lifetimeClaimed(ids[0]) + distBalanceD,
            120 ether,
            "received 100 + 20 = 120"
        );
    }

    /// @notice The user's exact scenario: many NFTs in a tier, one claims first,
    ///         then a new fee arrives. The NFT that already claimed must still
    ///         receive its proportional share of the NEW fee — same as everyone
    ///         else in the tier. Other NFTs hold (old + new). No double counting.
    function test_already_claimed_nft_still_gets_share_of_new_fees() public {
        // Mint 200 NFTs so we're statistically guaranteed several tiers populated.
        // We'll pick the first tier with ≥ 2 NFTs and run the scenario there.
        uint256[] memory ids = _adminMintAs(200);

        // Round 1: 10,000 OPOS arrives. Trigger sync via a no-op.
        _arriveFee(10_000 ether);
        distributor.sync();

        // Find any tier with ≥ 2 NFTs.
        uint8 testTier = 255;
        uint256 idA;
        uint256 idB;
        for (uint8 t = 0; t < 5; ++t) {
            if (distributor.activeInTier(t) >= 2) {
                testTier = t;
                break;
            }
        }
        assertLt(testTier, 5, "need a populated tier");
        // Find two ids in that tier.
        uint256 found;
        for (uint256 i = 0; i < ids.length && found < 2; ++i) {
            if (nft.tierIndexOf(ids[i]) == testTier) {
                if (found == 0) idA = ids[i]; else idB = ids[i];
                found++;
            }
        }

        uint256 nInTier = distributor.activeInTier(testTier);

        // Round 1 share per NFT in this tier:
        //   tierShare = 10,000 * 20% = 2000
        //   perNft   = 2000 / nInTier
        uint256 perNftRound1 = (2000 ether) / nInTier;
        // (Pending may have a few wei rounding; assert approx equal.)
        assertApproxEqAbs(distributor.pending(idA), perNftRound1, nInTier, "round 1 idA");
        assertApproxEqAbs(distributor.pending(idB), perNftRound1, nInTier, "round 1 idB");

        // ── NFT idA claims. Their pending goes to 0. idB still holds round-1 share. ──
        vm.prank(nft.ownerOf(idA));
        nft.claim(idA); // facade
        assertEq(distributor.pending(idA), 0, "idA pending zeroed after claim");
        assertApproxEqAbs(distributor.pending(idB), perNftRound1, nInTier, "idB unaffected");

        // ── Round 2: 100 OPOS arrives. ──
        _arriveFee(100 ether);
        distributor.sync();

        // Per-NFT share of the new 100 OPOS:
        //   tierShare = 100 * 20% = 20
        //   perNft   = 20 / nInTier
        uint256 perNftRound2 = (20 ether) / nInTier;

        // idA (who already claimed) gets exactly the new share — nothing more.
        assertApproxEqAbs(distributor.pending(idA), perNftRound2, nInTier, "idA gets new share only");

        // idB has (old + new): the round-1 share they never claimed, plus the round-2 share.
        assertApproxEqAbs(distributor.pending(idB), perNftRound1 + perNftRound2, nInTier, "idB has old + new");

        // The previously-claimed NFT is NOT excluded from new fees — it still earns
        // alongside everyone else. That's the property the user asked us to verify.
    }
}
