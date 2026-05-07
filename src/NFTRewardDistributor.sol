// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.6.0
pragma solidity ^0.8.34;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPixelCatsMetaHook {
    function emitMetadataUpdate(uint256 tokenId) external;
    function emitBatchMetadataUpdate() external;
}

/// @custom:security-contact hello@btb.finance
/// @notice Receives OPOS (or any ERC20) and distributes it equally across a fixed
///         set of NFT slots. Each NFT accrues a per-slot share automatically; the
///         current holder of a tokenId can claim its accumulated balance at any time.
///         If the holder transfers the NFT before claiming, unclaimed rewards travel
///         with the tokenId (the new owner can claim them).
contract NFTRewardDistributor is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Reward token (OPOS).
    IERC20 public immutable REWARD_TOKEN;

    /// @notice The NFT contract whose holders receive rewards.
    IERC721 public immutable NFT;

    /// @notice Fixed slot count. Every fee divides evenly across this many slots,
    ///         minted or not. Unminted slots accrue silently — when the slot is
    ///         eventually minted, the minter inherits the full backlog.
    uint256 public constant TOTAL_SLOTS = 88_888;

    /// @notice Precision for the cumulative index. 1e30 is comfortable headroom
    ///         when dividing 18-decimal token amounts by 88,888.
    uint256 private constant ACC_PRECISION = 1e30;

    /// @notice Cumulative reward per slot, scaled by ACC_PRECISION.
    uint256 public accRewardPerSlot;

    /// @notice Last reward-token balance recorded after a sync. Used to detect
    ///         new arrivals without requiring a hook from the token contract.
    uint256 public lastBalance;

    /// @notice Per-tokenId checkpoint of accRewardPerSlot at last claim.
    mapping(uint256 => uint256) public lastIndex;

    /// @notice Lifetime amount claimed against a tokenId (in token wei).
    mapping(uint256 => uint256) public lifetimeClaimed;

    event Claimed(address indexed claimer, uint256 indexed tokenId, uint256 amount);
    event Synced(uint256 newRewards, uint256 accRewardPerSlot);

    error InvalidTokenId();
    error NotNFTOwner();
    error ZeroAddress();

    constructor(address rewardToken, address nft) {
        if (rewardToken == address(0) || nft == address(0)) revert ZeroAddress();
        REWARD_TOKEN = IERC20(rewardToken);
        NFT = IERC721(nft);
    }

    // ─────────────────────────── views ───────────────────────────

    /// @notice Pending reward for a tokenId, in token wei (18 decimals).
    function pending(uint256 tokenId) public view returns (uint256) {
        if (tokenId == 0 || tokenId > TOTAL_SLOTS) revert InvalidTokenId();
        uint256 projected = _projectedAcc();
        return (projected - lastIndex[tokenId]) / ACC_PRECISION;
    }

    /// @notice Pending reward in whole token units (decimals stripped).
    function pendingWhole(uint256 tokenId) external view returns (uint256) {
        return pending(tokenId) / 1e18;
    }

    /// @notice Lifetime earned (claimed + pending) in token wei.
    function lifetimeEarned(uint256 tokenId) public view returns (uint256) {
        return lifetimeClaimed[tokenId] + pending(tokenId);
    }

    /// @notice Lifetime earned in whole token units (decimals stripped).
    function lifetimeEarnedWhole(uint256 tokenId) external view returns (uint256) {
        return lifetimeEarned(tokenId) / 1e18;
    }

    // ─────────────────────────── mutations ───────────────────────────

    /// @notice Claim a single tokenId's pending reward. Caller must own the NFT.
    function claim(uint256 tokenId) external nonReentrant {
        if (NFT.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();
        _sync();
        uint256 owed = (accRewardPerSlot - lastIndex[tokenId]) / ACC_PRECISION;
        lastIndex[tokenId] = accRewardPerSlot;
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
            uint256 owed = (accRewardPerSlot - lastIndex[id]) / ACC_PRECISION;
            lastIndex[id] = accRewardPerSlot;
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

    /// @notice Public sync — rolls newly arrived tokens into the index. Anyone may call
    ///         this to refresh marketplace metadata after a wave of fees has come in.
    function sync() external {
        if (_sync()) {
            _tryEmitBatchMetadataUpdate();
        }
    }

    // ─────────────────────────── internals ───────────────────────────

    function _sync() internal returns (bool changed) {
        uint256 currentBalance = REWARD_TOKEN.balanceOf(address(this));
        uint256 newRewards = currentBalance - lastBalance;
        if (newRewards > 0) {
            accRewardPerSlot += (newRewards * ACC_PRECISION) / TOTAL_SLOTS;
            lastBalance = currentBalance;
            emit Synced(newRewards, accRewardPerSlot);
            changed = true;
        }
    }

    function _projectedAcc() internal view returns (uint256) {
        uint256 currentBalance = REWARD_TOKEN.balanceOf(address(this));
        if (currentBalance <= lastBalance) return accRewardPerSlot;
        uint256 newRewards = currentBalance - lastBalance;
        return accRewardPerSlot + (newRewards * ACC_PRECISION) / TOTAL_SLOTS;
    }

    function _tryEmitMetadataUpdate(uint256 tokenId) internal {
        try IPixelCatsMetaHook(address(NFT)).emitMetadataUpdate(tokenId) {} catch {}
    }

    function _tryEmitBatchMetadataUpdate() internal {
        try IPixelCatsMetaHook(address(NFT)).emitBatchMetadataUpdate() {} catch {}
    }
}
