// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @notice Stand-in distributor whose yield views are directly settable.
///         The real distributor's payouts are bounded by fees actually sent in,
///         which makes the K/M/B display branches in OposNFT._formatAmount
///         impractical to reach. This mock lets a test dial `pending` and
///         `lifetimeEarned` to any value and assert on the rendered metadata.
///         It accepts mint notifications and does nothing with them.
contract MockYieldView {
    uint256 public pendingAmount;
    uint256 public lifetimeAmount;
    bool public sleeping;

    function setYield(uint256 _pending, uint256 _lifetime) external {
        pendingAmount = _pending;
        lifetimeAmount = _lifetime;
    }

    function setAsleep(bool v) external {
        sleeping = v;
    }

    // ── IRewardDistributorView ──
    function pending(uint256) external view returns (uint256) { return pendingAmount; }
    function lifetimeEarned(uint256) external view returns (uint256) { return lifetimeAmount; }
    function asleep(uint256) external view returns (bool) { return sleeping; }

    // ── IRewardDistributorMint ──
    function onMintBatch(uint256[] calldata) external {}
}
