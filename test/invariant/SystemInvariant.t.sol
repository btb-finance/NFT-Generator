// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";
import {Handler} from "./handlers/Handler.sol";

/// @notice Stateful invariant suite covering the global G* and cross-contract X*
///         properties from FUZZING.md. Foundry calls random handler functions
///         in random sequences; assertions must hold after every call.
contract SystemInvariantTest is TestBase {
    Handler public handler;

    function setUp() public override {
        super.setUp();
        handler = new Handler(nft, distributor, opos, owner, actors);

        // Restrict the invariant runner to the handler's surface so it doesn't
        // randomly call admin functions with unbounded values.
        targetContract(address(handler));
    }

    // ─────────────────────────── G1 — solvency ────────────────────────────────────

    /// @notice Distributor's OPOS balance must cover all claimable + pending.
    function invariant_G1_solvency() public {
        uint256 totalPending = _sumTierPending();
        uint256 totalUserClaimable;
        for (uint256 id = 1; id <= handler.ghost_maxId(); ++id) {
            totalUserClaimable += distributor.pending(id);
        }
        uint256 owed = totalPending + totalUserClaimable;
        uint256 have = opos.balanceOf(address(distributor));
        // Can have small surplus from dust; never less than owed.
        assertGe(have, owed, "G1: distributor under-collateralized");
    }

    // ─────────────────────────── G2 — conservation ────────────────────────────────

    /// @notice Every wei of fees received accounted for: claimed + pending +
    ///         tierPending + dust = total received. Tolerance of 100 wei per
    ///         sync × ~20 expected syncs in a deep run = generous bound.
    function invariant_G2_conservation() public {
        uint256 totalLifetime;
        uint256 totalPending;
        for (uint256 id = 1; id <= handler.ghost_maxId(); ++id) {
            totalLifetime += distributor.lifetimeClaimed(id);
            totalPending += distributor.pending(id);
        }
        uint256 tierPendingSum = _sumTierPending();
        uint256 accountedFor = totalLifetime + totalPending + tierPendingSum;
        uint256 received = handler.ghost_totalFeesReceived();
        // accountedFor ≤ received (we never invent fees);
        // received - accountedFor = dust (acceptable rounding)
        assertLe(accountedFor, received, "G2: more accounted than received");
        // Dust tolerance: PRECISION division loses up to (count) wei per tier per sync.
        // Conservative: 100,000 wei tolerance accommodates many syncs across many tiers.
        assertLe(received - accountedFor, 100_000, "G2: too much dust lost");
    }

    // ─────────────────────────── G5 — active count integrity ──────────────────────

    /// @notice activeInTier[t] equals the number of awake NFTs in tier t.
    function invariant_G5_active_count_match() public {
        uint256[5] memory awakeByTier;
        for (uint256 id = 1; id <= handler.ghost_maxId(); ++id) {
            if (!distributor.asleep(id)) {
                awakeByTier[nft.tierIndexOf(id)]++;
            }
        }
        for (uint8 t = 0; t < 5; ++t) {
            assertEq(distributor.activeInTier(t), awakeByTier[t], "G5: active count mismatch");
        }
    }

    // ─────────────────────────── G7 — tier purity ─────────────────────────────────

    /// @notice tierIndexOf is deterministic — calling twice returns the same value.
    ///         Sample a few ids per invariant call (calling all of them is too slow).
    function invariant_G7_tier_stable() public {
        uint256 maxId = handler.ghost_maxId();
        if (maxId == 0) return;
        uint256[5] memory sampleIds = [
            uint256(1), maxId / 4 + 1, maxId / 2 + 1, (maxId * 3) / 4 + 1, maxId
        ];
        for (uint256 i = 0; i < sampleIds.length; ++i) {
            if (sampleIds[i] == 0 || sampleIds[i] > maxId) continue;
            uint8 a = nft.tierIndexOf(sampleIds[i]);
            uint8 b = nft.tierIndexOf(sampleIds[i]);
            assertEq(a, b, "G7: tier not stable");
            assertLe(a, 4, "G7: tier out of range");
        }
    }

    // ─────────────────────────── X1 — NFT ↔ distributor count ─────────────────────

    /// @notice activeInTier sum + asleep sum = totalSupply().
    function invariant_X1_supply_accounting() public {
        uint256 active = _sumActive();
        uint256 asleepCount;
        for (uint256 id = 1; id <= handler.ghost_maxId(); ++id) {
            if (distributor.asleep(id)) asleepCount++;
        }
        assertEq(active + asleepCount, nft.totalSupply(), "X1: supply mismatch");
    }

    // ─────────────────────────── supply cap ───────────────────────────────────────

    function invariant_supply_within_cap() public {
        assertLe(nft.totalSupply(), nft.MAX_SUPPLY(), "supply > MAX_SUPPLY");
    }

    // ─────────────────────────── debugging summary ────────────────────────────────

    /// @notice Not an invariant — printed only when other invariants fail or via -vv.
    function invariant_callSummary() public view {
        // Foundry prints view returns only with -vvv; this gives us a coverage hint.
        // (No assertion — purely informational via console if you wire it.)
    }
}
