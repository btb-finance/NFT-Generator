// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.6.0
pragma solidity ^0.8.34;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IMetadataUpdateHook {
    function emitMetadataUpdate(uint256 tokenId) external;
    function emitBatchMetadataUpdate() external;
}

interface ITieredNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function tierIndexOf(uint256 tokenId) external view returns (uint8);
}

/// @custom:security-contact hello@btb.finance
/// @notice Tier-weighted reward distributor for the OPOSSUM NFT collection.
///
///         Every fee that lands in this contract is split evenly across 5 rarity
///         tiers (20% each), and each tier's share is divided by the tier's
///         actual minted count. So a Mythic earns far more per-NFT than a Common
///         simply because there are far fewer Mythics.
///
///         If a tier has 0 minted NFTs when fees arrive, that tier's 20% sits in
///         a per-tier pending bucket. When the first NFT of that tier mints, the
///         backlog is released to existing tier holders (i.e., that single first
///         minter of an empty tier inherits the pending share).
///
///         Rewards travel with the tokenId — transferring an NFT carries any
///         unclaimed balance to the new owner, so no staking is required.
contract NFTRewardDistributor is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant TIERS = 5;
    uint256 public constant TIER_BPS = 2000;       // 20% per tier
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant ACC_PRECISION = 1e30;

    IERC20 public immutable REWARD_TOKEN;
    ITieredNFT public immutable NFT;

    /// @notice Cumulative reward-per-NFT for each tier, scaled by ACC_PRECISION.
    uint256[5] public accRewardPerSlot;

    /// @notice Per-tier share that has accrued before any NFT in that tier
    ///         existed. Released to the first NFT(s) that mint into the tier.
    uint256[5] public tierPending;

    /// @notice Number of NFTs minted into each tier. Source of truth for
    ///         per-tier divisor used when distributing rewards.
    uint256[5] public mintedInTier;

    /// @notice Total reward-token balance recorded after the last sync.
    uint256 public lastBalance;

    /// @notice Per-tokenId checkpoint of the tier's accRewardPerSlot at last
    ///         claim or mint time.
    mapping(uint256 => uint256) public lastIndex;

    /// @notice Lifetime token wei claimed against a tokenId.
    mapping(uint256 => uint256) public lifetimeClaimed;

    event Claimed(address indexed claimer, uint256 indexed tokenId, uint256 amount);
    event Synced(uint256 newRewards);
    event TierMint(uint256 indexed tokenId, uint8 indexed tier, uint256 newCount);
    event PendingReleased(uint8 indexed tier, uint256 amount);

    error NotNFTOwner();
    error NotNFT();
    error ZeroAddress();
    error InvalidTier();

    constructor(address rewardToken, address nft) {
        if (rewardToken == address(0) || nft == address(0)) revert ZeroAddress();
        REWARD_TOKEN = IERC20(rewardToken);
        NFT = ITieredNFT(nft);
    }

    // ─────────────────────────── views ───────────────────────────

    /// @notice Pending reward for a tokenId, in token wei.
    function pendingReward(uint256 tokenId) public view returns (uint256) {
        uint8 tier = NFT.tierIndexOf(tokenId);
        uint256 projected = _projectedAcc(tier);
        return (projected - lastIndex[tokenId]) / ACC_PRECISION;
    }

    /// @notice Same name as the previous distributor for ABI continuity with
    ///         OposNFT's `IRewardDistributorView`.
    function pending(uint256 tokenId) external view returns (uint256) {
        return pendingReward(tokenId);
    }

    /// @notice Pending reward in whole token units (decimals stripped).
    function pendingWhole(uint256 tokenId) external view returns (uint256) {
        return pendingReward(tokenId) / 1e18;
    }

    /// @notice Lifetime earned (claimed + currently pending) in token wei.
    function lifetimeEarned(uint256 tokenId) public view returns (uint256) {
        return lifetimeClaimed[tokenId] + pendingReward(tokenId);
    }

    /// @notice Lifetime earned in whole token units.
    function lifetimeEarnedWhole(uint256 tokenId) external view returns (uint256) {
        return lifetimeEarned(tokenId) / 1e18;
    }

    /// @notice The tier-weighted "yield multiplier" for a given tier vs Common,
    ///         based on current minted counts. Returns 0 if any required count
    ///         is zero. Useful for UIs.
    function yieldMultiplier(uint8 tier) external view returns (uint256) {
        if (tier >= TIERS) revert InvalidTier();
        uint256 commonCount = mintedInTier[4];
        uint256 tierCount = mintedInTier[tier];
        if (commonCount == 0 || tierCount == 0) return 0;
        // Each tier earns the same total share, so per-NFT ratio is commonCount/tierCount.
        return (commonCount * 100) / tierCount; // returns ×100 (e.g., 6500 = 65×)
    }

    // ─────────────────────────── mutations ───────────────────────────

    /// @notice Claim a single tokenId's pending reward. Caller must own the NFT.
    function claim(uint256 tokenId) external nonReentrant {
        if (NFT.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();
        _sync();
        uint8 tier = NFT.tierIndexOf(tokenId);
        uint256 owed = (accRewardPerSlot[tier] - lastIndex[tokenId]) / ACC_PRECISION;
        lastIndex[tokenId] = accRewardPerSlot[tier];
        if (owed > 0) {
            lifetimeClaimed[tokenId] += owed;
            lastBalance -= owed;
            REWARD_TOKEN.safeTransfer(msg.sender, owed);
            _tryEmitMetadataUpdate(tokenId);
            emit Claimed(msg.sender, tokenId, owed);
        }
    }

    /// @notice Claim multiple tokenIds in one call. All must be owned by the caller.
    function claimMany(uint256[] calldata tokenIds) external nonReentrant {
        _sync();
        uint256 total;
        uint256 len = tokenIds.length;
        for (uint256 i; i < len; ++i) {
            uint256 id = tokenIds[i];
            if (NFT.ownerOf(id) != msg.sender) revert NotNFTOwner();
            uint8 tier = NFT.tierIndexOf(id);
            uint256 owed = (accRewardPerSlot[tier] - lastIndex[id]) / ACC_PRECISION;
            lastIndex[id] = accRewardPerSlot[tier];
            if (owed > 0) {
                lifetimeClaimed[id] += owed;
                total += owed;
                emit Claimed(msg.sender, id, owed);
            }
        }
        if (total > 0) {
            lastBalance -= total;
            REWARD_TOKEN.safeTransfer(msg.sender, total);
            _tryEmitBatchMetadataUpdate();
        }
    }

    /// @notice Public sync — anyone can call to refresh the per-tier indices and
    ///         nudge marketplaces (via ERC-4906) to refresh metadata.
    function sync() external {
        if (_sync()) {
            _tryEmitBatchMetadataUpdate();
        }
    }

    /// @notice Called by the NFT contract right after a batch mint. Snapshots
    ///         lastIndex for each new tokenId at the current tier index, then
    ///         increments tier counts. If a tier transitions from 0→N in this
    ///         batch, its pending share is released to the new minters.
    function onMintBatch(uint256[] calldata tokenIds) external {
        if (msg.sender != address(NFT)) revert NotNFT();
        _sync();

        // Track which tiers are seeing their first mint(s) in this batch.
        uint256[5] memory countsBefore = [
            mintedInTier[0], mintedInTier[1], mintedInTier[2],
            mintedInTier[3], mintedInTier[4]
        ];

        uint256 len = tokenIds.length;
        for (uint256 i; i < len; ++i) {
            uint256 id = tokenIds[i];
            uint8 tier = NFT.tierIndexOf(id);
            // Snapshot BEFORE any pending-release update so brand-new minters
            // in an empty tier still earn that tier's backlog.
            lastIndex[id] = accRewardPerSlot[tier];
            unchecked { mintedInTier[tier] += 1; }
            emit TierMint(id, tier, mintedInTier[tier]);
        }

        // Release pending for any tier that went from 0 minted to N>0 in this batch.
        for (uint8 t; t < TIERS; ++t) {
            if (countsBefore[t] == 0 && mintedInTier[t] > 0 && tierPending[t] > 0) {
                accRewardPerSlot[t] += (tierPending[t] * ACC_PRECISION) / mintedInTier[t];
                emit PendingReleased(t, tierPending[t]);
                tierPending[t] = 0;
            }
        }
    }

    // ─────────────────────────── internals ───────────────────────────

    function _sync() internal returns (bool changed) {
        uint256 currentBalance = REWARD_TOKEN.balanceOf(address(this));
        if (currentBalance <= lastBalance) return false;
        uint256 newRewards = currentBalance - lastBalance;
        lastBalance = currentBalance;

        // Split fees across the 5 tiers; uneven dust (mod 5) stays in the
        // contract as a rounding remainder.
        for (uint8 t; t < TIERS; ++t) {
            uint256 share = (newRewards * TIER_BPS) / BPS_DENOMINATOR;
            if (mintedInTier[t] > 0) {
                accRewardPerSlot[t] += (share * ACC_PRECISION) / mintedInTier[t];
            } else {
                tierPending[t] += share;
            }
        }
        emit Synced(newRewards);
        return true;
    }

    function _projectedAcc(uint8 tier) internal view returns (uint256) {
        uint256 currentBalance = REWARD_TOKEN.balanceOf(address(this));
        if (currentBalance <= lastBalance || mintedInTier[tier] == 0) {
            return accRewardPerSlot[tier];
        }
        uint256 newRewards = currentBalance - lastBalance;
        uint256 share = (newRewards * TIER_BPS) / BPS_DENOMINATOR;
        return accRewardPerSlot[tier] + (share * ACC_PRECISION) / mintedInTier[tier];
    }

    function _tryEmitMetadataUpdate(uint256 tokenId) internal {
        try IMetadataUpdateHook(address(NFT)).emitMetadataUpdate(tokenId) {} catch {}
    }

    function _tryEmitBatchMetadataUpdate() internal {
        try IMetadataUpdateHook(address(NFT)).emitBatchMetadataUpdate() {} catch {}
    }
}
