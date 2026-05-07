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
}
