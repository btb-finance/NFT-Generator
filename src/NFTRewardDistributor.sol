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
/// @notice Tier-weighted reward distributor with a sleep/reap mechanic that
///         keeps holders active.
///
///         Fees split 20% per tier; each tier's share divides by the tier's
///         currently-active count. NFTs that go 100+ days without claiming can
///         be "reaped" by anyone — the reaper takes the unclaimed rewards and
///         the NFT goes to sleep (no longer earns). The owner must call wake()
///         to bring it back online.
///
///         Sleeping NFTs leave the divisor, so their would-be share goes to
///         active holders of the same tier. Active users earn more when the
///         lazy ones drop out — which is the whole point.
///
/// @dev    REWARD_TOKEN requirements: transferring X must debit the sender's
///         balance by exactly X, and balances must never change on their own
///         (no rebasing) — the `lastBalance` accounting diffs this contract's
///         own balance. A transfer tax absorbed by the RECIPIENT (sender
///         debited exactly X, like OPOSSUM's 1%) is therefore compatible, but
///         claim payouts would arrive 1% short of the displayed pending.
///         Production wiring: set this distributor as the OPOS treasury —
///         trade taxes then flow in here directly and outbound claims are
///         tax-exempt (`from == treasury`), so holders receive exactly what
///         their NFT displays. Rounding dust from the per-tier splits stays
///         in the contract as unclaimable wei — intentional and economically
///         negligible, not a leak.
contract NFTRewardDistributor is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant TIERS = 5;
    uint256 public constant TIER_BPS = 2000;          // 20% per tier
    uint256 public constant SLEEP_THRESHOLD = 100 days;

    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant ACC_PRECISION = 1e30;

    IERC20 public immutable REWARD_TOKEN;
    ITieredNFT public immutable NFT;

    /// @notice Cumulative reward-per-NFT for each tier, scaled by ACC_PRECISION.
    uint256[5] public accRewardPerSlot;

    /// @notice Per-tier share that has accrued while a tier had 0 active NFTs.
    ///         Released when the tier transitions back to ≥1 active member.
    uint256[5] public tierPending;

    /// @notice Currently ACTIVE NFTs in each tier (minted minus asleep).
    ///         This is the divisor used to split a tier's 20% share.
    uint256[5] public activeInTier;

    /// @notice Total reward-token balance recorded after the last sync.
    uint256 public lastBalance;

    /// @notice Per-tokenId checkpoint of the tier's accRewardPerSlot.
    mapping(uint256 => uint256) public lastIndex;

    /// @notice Lifetime token wei claimed (or reaped) against a tokenId.
    mapping(uint256 => uint256) public lifetimeClaimed;

    /// @notice Last time a tokenId did something that counts as "active":
    ///         minted, claimed, or woken. Used to enforce SLEEP_THRESHOLD.
    mapping(uint256 => uint256) public lastActivityAt;

    /// @notice Whether a tokenId has been reaped and is currently dormant.
    ///         Asleep NFTs do not earn rewards and are excluded from the divisor.
    mapping(uint256 => bool) public asleep;

    /// @notice TokenIds the NFT contract registered via onMintBatch. Claim,
    ///         reap, and wake all require registration, so the distributor
    ///         never pays out against an id it wasn't told about — even if the
    ///         NFT contract's tierIndexOf were to misbehave for unknown ids.
    mapping(uint256 => bool) public registered;

    event Claimed(address indexed claimer, uint256 indexed tokenId, uint256 amount);
    event Synced(uint256 newRewards);
    event TierMint(uint256 indexed tokenId, uint8 indexed tier, uint256 newActiveCount);
    event PendingReleased(uint8 indexed tier, uint256 amount);
    event Reaped(address indexed reaper, uint256 indexed tokenId, uint256 amount);
    event Woke(address indexed owner, uint256 indexed tokenId);
    event MetadataUpdateFailed(uint256 indexed tokenId);
    event BatchMetadataUpdateFailed();

    error NotNFTOwner();
    error NotNFT();
    error ZeroAddress();
    error InvalidTier();
    error NFTAsleep();
    error NotAsleep();
    error NotStaleYet();
    error BatchTooLarge();
    error EmptyBatch();
    error NotRegistered();

    constructor(address rewardToken, address nft) {
        if (rewardToken == address(0) || nft == address(0)) revert ZeroAddress();
        REWARD_TOKEN = IERC20(rewardToken);
        NFT = ITieredNFT(nft);
    }

    // ─────────────────────────── views ───────────────────────────

    /// @notice Pending reward for a tokenId, in token wei. Returns 0 if asleep
    ///         or never registered.
    function pendingReward(uint256 tokenId) public view returns (uint256) {
        if (!registered[tokenId] || asleep[tokenId]) return 0;
        uint8 tier = NFT.tierIndexOf(tokenId);
        uint256 projected = _projectedAcc(tier);
        return (projected - lastIndex[tokenId]) / ACC_PRECISION;
    }

    /// @notice ABI-compatible view used by OposNFT's `IRewardDistributorView`.
    function pending(uint256 tokenId) external view returns (uint256) {
        return pendingReward(tokenId);
    }

    function pendingWhole(uint256 tokenId) external view returns (uint256) {
        return pendingReward(tokenId) / 1e18;
    }

    function lifetimeEarned(uint256 tokenId) public view returns (uint256) {
        return lifetimeClaimed[tokenId] + pendingReward(tokenId);
    }

    function lifetimeEarnedWhole(uint256 tokenId) external view returns (uint256) {
        return lifetimeEarned(tokenId) / 1e18;
    }

    /// @notice Per-NFT yield ratio of `tier` vs Common, ×100 (e.g., 6500 = 65×).
    ///         Based on currently-active counts, so dormant NFTs amplify the
    ///         multiplier for their active peers.
    function yieldMultiplier(uint8 tier) external view returns (uint256) {
        if (tier >= TIERS) revert InvalidTier();
        uint256 commonCount = activeInTier[4];
        uint256 tierCount = activeInTier[tier];
        if (commonCount == 0 || tierCount == 0) return 0;
        return (commonCount * 100) / tierCount;
    }

    /// @notice True if the NFT can currently be reaped (stale ≥ SLEEP_THRESHOLD
    ///         and not already asleep).
    function isReapable(uint256 tokenId) external view returns (bool) {
        if (asleep[tokenId]) return false;
        return block.timestamp >= lastActivityAt[tokenId] + SLEEP_THRESHOLD;
    }

    /// @notice Seconds remaining before this tokenId becomes reapable. Returns
    ///         0 if already past the threshold or already asleep.
    function secondsUntilStale(uint256 tokenId) public view returns (uint256) {
        if (asleep[tokenId]) return 0;
        uint256 deadline = lastActivityAt[tokenId] + SLEEP_THRESHOLD;
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }

    /// @notice Bulk status read for frontends and reaper bots: one eth_call
    ///         covers many tokenIds instead of three calls per token.
    ///         Unregistered ids report (0, 0, false) rather than reverting.
    /// @dev    View-only; each id costs a few external reads, so keep batches
    ///         to ~1,000 ids per call to stay inside RPC gas caps.
    function statusBatch(uint256[] calldata tokenIds)
        external
        view
        returns (
            uint256[] memory secondsLeft,
            uint256[] memory pendingAmounts,
            bool[] memory sleeping
        )
    {
        uint256 len = tokenIds.length;
        secondsLeft = new uint256[](len);
        pendingAmounts = new uint256[](len);
        sleeping = new bool[](len);
        for (uint256 i; i < len; ++i) {
            uint256 id = tokenIds[i];
            sleeping[i] = asleep[id];
            pendingAmounts[i] = pendingReward(id);
            secondsLeft[i] = secondsUntilStale(id);
        }
    }

    // ─────────────────────────── core mutations ───────────────────────────

    /// @notice Claim a single tokenId's pending reward. Caller must own the NFT
    ///         and the NFT must be awake.
    function claim(uint256 tokenId) external nonReentrant {
        _claim(msg.sender, tokenId);
    }

    /// @notice NFT-contract-only facade so users can claim via `nft.claim()`
    ///         without knowing the distributor address. The NFT vouches for
    ///         the user; we still verify they own the NFT.
    function claimFor(address user, uint256 tokenId) external nonReentrant {
        if (msg.sender != address(NFT)) revert NotNFT();
        _claim(user, tokenId);
    }

    /// @notice Maximum tokenIds in a single `claimMany` call. Bounds gas so a
    ///         user with many NFTs splits the work across a few transactions.
    uint256 public constant MAX_CLAIM_BATCH = 100;

    /// @notice Claim multiple tokenIds in one call. Reverts if any is asleep
    ///         or if the array exceeds MAX_CLAIM_BATCH.
    function claimMany(uint256[] calldata tokenIds) external nonReentrant {
        if (tokenIds.length == 0) revert EmptyBatch();
        if (tokenIds.length > MAX_CLAIM_BATCH) revert BatchTooLarge();
        _claimMany(msg.sender, tokenIds);
    }

    /// @notice NFT-contract-only facade for batch claim.
    function claimManyFor(address user, uint256[] calldata tokenIds) external nonReentrant {
        if (msg.sender != address(NFT)) revert NotNFT();
        if (tokenIds.length == 0) revert EmptyBatch();
        if (tokenIds.length > MAX_CLAIM_BATCH) revert BatchTooLarge();
        _claimMany(user, tokenIds);
    }

    function _claim(address user, uint256 tokenId) internal {
        if (!registered[tokenId]) revert NotRegistered();
        if (NFT.ownerOf(tokenId) != user) revert NotNFTOwner();
        if (asleep[tokenId]) revert NFTAsleep();
        _sync();
        uint8 tier = NFT.tierIndexOf(tokenId);
        uint256 owed = (accRewardPerSlot[tier] - lastIndex[tokenId]) / ACC_PRECISION;
        lastIndex[tokenId] = accRewardPerSlot[tier];
        lastActivityAt[tokenId] = block.timestamp;
        if (owed > 0) {
            lifetimeClaimed[tokenId] += owed;
            lastBalance -= owed;
            REWARD_TOKEN.safeTransfer(user, owed);
            _tryEmitMetadataUpdate(tokenId);
            emit Claimed(user, tokenId, owed);
        }
    }

    function _claimMany(address user, uint256[] calldata tokenIds) internal {
        _sync();
        uint256 total;
        uint256 len = tokenIds.length;
        for (uint256 i; i < len; ++i) {
            uint256 id = tokenIds[i];
            if (!registered[id]) revert NotRegistered();
            if (NFT.ownerOf(id) != user) revert NotNFTOwner();
            if (asleep[id]) revert NFTAsleep();
            uint8 tier = NFT.tierIndexOf(id);
            uint256 owed = (accRewardPerSlot[tier] - lastIndex[id]) / ACC_PRECISION;
            lastIndex[id] = accRewardPerSlot[tier];
            lastActivityAt[id] = block.timestamp;
            if (owed > 0) {
                lifetimeClaimed[id] += owed;
                total += owed;
                emit Claimed(user, id, owed);
            }
        }
        if (total > 0) {
            lastBalance -= total;
            REWARD_TOKEN.safeTransfer(user, total);
            _tryEmitBatchMetadataUpdate();
        }
    }

    /// @notice Public sync — anyone can refresh the per-tier indices.
    function sync() external {
        if (_sync()) {
            _tryEmitBatchMetadataUpdate();
        }
    }

    // ─────────────────────────── sleep / reap ───────────────────────────

    /// @notice Reap a stale NFT. Anyone can call after SLEEP_THRESHOLD has
    ///         passed since the NFT's last activity. Caller takes 100% of the
    ///         pending reward; the NFT is marked asleep and stops earning.
    ///         Emits Reaped even when nothing was owed, so indexers tracking
    ///         sleep state never miss a transition.
    function reap(uint256 tokenId) external nonReentrant {
        if (!registered[tokenId]) revert NotRegistered();
        if (asleep[tokenId]) revert NFTAsleep();
        if (block.timestamp < lastActivityAt[tokenId] + SLEEP_THRESHOLD) revert NotStaleYet();
        _sync();
        uint8 tier = NFT.tierIndexOf(tokenId);
        uint256 owed = (accRewardPerSlot[tier] - lastIndex[tokenId]) / ACC_PRECISION;
        lastIndex[tokenId] = accRewardPerSlot[tier];
        asleep[tokenId] = true;
        // Every registered, awake token is counted in activeInTier, so this
        // cannot underflow; checked math turns any future violation of that
        // invariant into a loud revert instead of a corrupted divisor.
        activeInTier[tier] -= 1;
        _tryEmitMetadataUpdate(tokenId);
        if (owed > 0) {
            lifetimeClaimed[tokenId] += owed;
            lastBalance -= owed;
            REWARD_TOKEN.safeTransfer(msg.sender, owed);
        }
        emit Reaped(msg.sender, tokenId, owed);
    }

    /// @notice Wake a sleeping NFT. Only callable by the current owner. The NFT
    ///         starts earning again from the moment it's woken — it does NOT
    ///         retroactively claim rewards that grew during its sleep.
    function wake(uint256 tokenId) external nonReentrant {
        _sync();
        _wakeOne(msg.sender, tokenId);
        _tryEmitMetadataUpdate(tokenId);
    }

    /// @notice NFT-contract-only facade so users can wake via `nft.wake()`.
    function wakeFor(address user, uint256 tokenId) external nonReentrant {
        if (msg.sender != address(NFT)) revert NotNFT();
        _sync();
        _wakeOne(user, tokenId);
        _tryEmitMetadataUpdate(tokenId);
    }

    /// @notice Wake multiple sleeping NFTs in one call (e.g., after buying a
    ///         batch of reaped NFTs on a marketplace). Caller must own every
    ///         tokenId, all must be asleep, and the array is capped at
    ///         MAX_CLAIM_BATCH.
    function wakeMany(uint256[] calldata tokenIds) external nonReentrant {
        if (tokenIds.length == 0) revert EmptyBatch();
        if (tokenIds.length > MAX_CLAIM_BATCH) revert BatchTooLarge();
        _wakeMany(msg.sender, tokenIds);
    }

    /// @notice NFT-contract-only facade for batch wake.
    function wakeManyFor(address user, uint256[] calldata tokenIds) external nonReentrant {
        if (msg.sender != address(NFT)) revert NotNFT();
        if (tokenIds.length == 0) revert EmptyBatch();
        if (tokenIds.length > MAX_CLAIM_BATCH) revert BatchTooLarge();
        _wakeMany(user, tokenIds);
    }

    function _wakeMany(address user, uint256[] calldata tokenIds) internal {
        _sync();
        uint256 len = tokenIds.length;
        for (uint256 i; i < len; ++i) {
            _wakeOne(user, tokenIds[i]);
        }
        _tryEmitBatchMetadataUpdate();
    }

    /// @dev Per-token wake logic. Caller is responsible for running _sync()
    ///      first and emitting the appropriate metadata-update signal.
    function _wakeOne(address user, uint256 tokenId) internal {
        if (!registered[tokenId]) revert NotRegistered();
        if (NFT.ownerOf(tokenId) != user) revert NotNFTOwner();
        if (!asleep[tokenId]) revert NotAsleep();

        uint8 tier = NFT.tierIndexOf(tokenId);
        uint256 prevActive = activeInTier[tier];

        lastIndex[tokenId] = accRewardPerSlot[tier];
        asleep[tokenId] = false;
        unchecked { activeInTier[tier] = prevActive + 1; }
        lastActivityAt[tokenId] = block.timestamp;

        if (prevActive == 0 && tierPending[tier] > 0) {
            // activeInTier[tier] is exactly 1 here (we just incremented from 0),
            // but use the array read explicitly for clarity and parity with
            // onMintBatch's pending-release loop. In a batch wake, only the
            // FIRST token of a previously-empty tier inherits the backlog —
            // identical to waking them one by one in the same order.
            accRewardPerSlot[tier] += (tierPending[tier] * ACC_PRECISION) / activeInTier[tier];
            emit PendingReleased(tier, tierPending[tier]);
            tierPending[tier] = 0;
        }

        emit Woke(user, tokenId);
    }

    // ─────────────────────────── mint hook ───────────────────────────

    /// @notice Called by the NFT contract right after a batch mint.
    function onMintBatch(uint256[] calldata tokenIds) external {
        if (msg.sender != address(NFT)) revert NotNFT();
        _sync();

        uint256[5] memory countsBefore = [
            activeInTier[0], activeInTier[1], activeInTier[2],
            activeInTier[3], activeInTier[4]
        ];

        uint256 nowTs = block.timestamp;
        uint256 len = tokenIds.length;
        for (uint256 i; i < len; ++i) {
            uint256 id = tokenIds[i];
            uint8 tier = NFT.tierIndexOf(id);
            // Snapshot BEFORE pending release so first minters of an empty tier
            // still earn that tier's backlog.
            lastIndex[id] = accRewardPerSlot[tier];
            lastActivityAt[id] = nowTs;
            registered[id] = true;
            unchecked { activeInTier[tier] += 1; }
            emit TierMint(id, tier, activeInTier[tier]);
        }

        // Release pending for tiers that went from 0 → N>0 in this batch.
        for (uint8 t; t < TIERS; ++t) {
            if (countsBefore[t] == 0 && activeInTier[t] > 0 && tierPending[t] > 0) {
                accRewardPerSlot[t] += (tierPending[t] * ACC_PRECISION) / activeInTier[t];
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

        uint256 share = (newRewards * TIER_BPS) / BPS_DENOMINATOR;
        for (uint8 t; t < TIERS; ++t) {
            if (activeInTier[t] > 0) {
                accRewardPerSlot[t] += (share * ACC_PRECISION) / activeInTier[t];
            } else {
                tierPending[t] += share;
            }
        }
        emit Synced(newRewards);
        return true;
    }

    function _projectedAcc(uint8 tier) internal view returns (uint256) {
        uint256 currentBalance = REWARD_TOKEN.balanceOf(address(this));
        if (currentBalance <= lastBalance || activeInTier[tier] == 0) {
            return accRewardPerSlot[tier];
        }
        uint256 newRewards = currentBalance - lastBalance;
        uint256 share = (newRewards * TIER_BPS) / BPS_DENOMINATOR;
        return accRewardPerSlot[tier] + (share * ACC_PRECISION) / activeInTier[tier];
    }

    function _tryEmitMetadataUpdate(uint256 tokenId) internal {
        try IMetadataUpdateHook(address(NFT)).emitMetadataUpdate(tokenId) {} catch {
            emit MetadataUpdateFailed(tokenId);
        }
    }

    function _tryEmitBatchMetadataUpdate() internal {
        try IMetadataUpdateHook(address(NFT)).emitBatchMetadataUpdate() {} catch {
            emit BatchMetadataUpdateFailed();
        }
    }
}
