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

    // ───────────── Takeover support ─────────────
    // A replacement distributor is deployed AFTER tokens already exist, so it
    // can never receive the onMintBatch calls that registered them. Rather than
    // enrolling 88,888 tokens one by one (millions of gas, and unfair while
    // half-done because activeInTier is the reward divisor), a takeover
    // deployment inherits them: every id up to INHERITED_SUPPLY counts as
    // registered from birth, and the tier divisors are seeded at construction.
    //
    // Nothing is copied from the old contract and no admin supplies balances.
    // The predecessor keeps its own funds and stays fully usable — its claim()
    // is public and authorises against the NFT, so holders can always withdraw
    // rewards accrued there even after the NFT points somewhere else.

    /// @notice Highest tokenId this deployment treats as pre-registered.
    ///         Zero for a first deployment.
    uint256 public immutable INHERITED_SUPPLY;

    /// @notice Deployment timestamp. Inherited tokens have no recorded
    ///         activity, so their sleep clock starts here rather than at the
    ///         epoch — otherwise every one of them would be instantly reapable.
    uint256 public immutable ACTIVATED_AT;

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

    // ───────────── Mint batches (see onMintBatch) ─────────────
    // Minting used to write three cold slots per token — `registered`,
    // `lastActivityAt` and `lastIndex` — about 66k gas each token, roughly half
    // the total mint cost. All three were the SAME value for every token in a
    // batch, so they are recorded once per batch and derived on read instead.
    // Per-token slots are now written only when a token actually claims, reaps
    // or wakes, paid for by whoever does it.

    struct MintBatch {
        uint32 firstId;   // batches are contiguous ascending id ranges
        uint32 lastId;
        uint48 mintedAt;  // starts the sleep clock for every token in it
    }

    /// @notice One entry per mint, ordered by firstId. Binary-searched on read.
    MintBatch[] public mintBatches;

    /// @notice accRewardPerSlot per tier at the moment a batch was minted —
    ///         the `lastIndex` its tokens start from.
    mapping(uint256 => uint256[5]) private batchAcc;

    /// @notice Number of recorded mint batches.
    function mintBatches_length() external view returns (uint256) {
        return mintBatches.length;
    }

    /// @notice Highest tokenId this distributor has been told about. Derived
    ///         from the last batch rather than stored — one fewer cold SSTORE
    ///         per mint, which matters most for single-token buys where there
    ///         is no batch to amortise it over.
    function highestMinted() public view returns (uint256) {
        uint256 n = mintBatches.length;
        return n == 0 ? 0 : mintBatches[n - 1].lastId;
    }

    event Claimed(address indexed claimer, uint256 indexed tokenId, uint256 amount);
    event Synced(uint256 newRewards);
    /// @dev One event per batch rather than per token: the per-token event
    ///      cost ~1,900 gas each and carried nothing a range cannot express.
    event TierMintBatch(uint256 indexed firstId, uint256 indexed lastId, uint256[5] perTier);
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
    error NonContiguousBatch();

    /**
     * @param rewardToken     Token rewards are paid in.
     * @param nft             The collection this distributor serves.
     * @param inheritedSupply Tokens 1..inheritedSupply are treated as already
     *                        registered. Pass 0 for a first deployment; pass
     *                        the live supply when replacing an existing
     *                        distributor.
     * @param seedActive      Starting active count per tier. Pass all zeros for
     *                        a first deployment. For a takeover these are the
     *                        awake token counts per tier — publicly checkable
     *                        from the NFT before the migration timelock ends.
     */
    constructor(
        address rewardToken,
        address nft,
        uint256 inheritedSupply,
        uint256[5] memory seedActive
    ) {
        if (rewardToken == address(0) || nft == address(0)) revert ZeroAddress();
        REWARD_TOKEN = IERC20(rewardToken);
        NFT = ITieredNFT(nft);
        INHERITED_SUPPLY = inheritedSupply;
        ACTIVATED_AT = block.timestamp;
        for (uint8 t; t < TIERS; ++t) {
            activeInTier[t] = seedActive[t];
        }
    }

    /// @notice Whether this distributor recognises `tokenId`. Derived from the
    ///         minted range rather than a per-token flag, which is what removes
    ///         a cold SSTORE from every mint.
    function registered(uint256 tokenId) public view returns (bool) {
        if (tokenId == 0) return false;
        return tokenId <= highestMinted() || tokenId <= INHERITED_SUPPLY;
    }

    function _isRegistered(uint256 tokenId) internal view returns (bool) {
        return registered(tokenId);
    }

    /// @dev Index of the batch containing `tokenId`, if any. Inherited tokens
    ///      predate this contract and have no batch.
    function _batchOf(uint256 tokenId) internal view returns (bool found, uint256 index) {
        uint256 n = mintBatches.length;
        if (n == 0) return (false, 0);
        // Last batch whose firstId is <= tokenId.
        uint256 lo;
        uint256 hi = n;
        while (lo < hi) {
            uint256 mid = (lo + hi) >> 1;
            if (mintBatches[mid].firstId <= tokenId) lo = mid + 1;
            else hi = mid;
        }
        if (lo == 0) return (false, 0);
        index = lo - 1;
        if (tokenId > mintBatches[index].lastId) return (false, 0);
        found = true;
    }

    /**
     * @dev The token's reward checkpoint. A non-zero per-token value always
     *      wins; zero means the token has never claimed, reaped or woken, so it
     *      still sits on its batch's snapshot.
     *
     *      Zero is safe as the "unset" marker: every write to lastIndex stores
     *      accRewardPerSlot[tier], which is monotonic and always >= the batch
     *      snapshot. If it writes zero then the snapshot is zero too, so both
     *      readings agree.
     */
    function _indexOf(uint256 tokenId, uint8 tier) internal view returns (uint256) {
        uint256 stored = lastIndex[tokenId];
        if (stored != 0) return stored;
        (bool found, uint256 index) = _batchOf(tokenId);
        return found ? batchAcc[index][tier] : 0;
    }

    /// @dev Last activity: the per-token value, else the batch's mint time,
    ///      else (for inherited tokens) this contract's deployment.
    function _activityAt(uint256 tokenId) internal view returns (uint256) {
        uint256 at = lastActivityAt[tokenId];
        if (at != 0) return at;
        (bool found, uint256 index) = _batchOf(tokenId);
        return found ? mintBatches[index].mintedAt : ACTIVATED_AT;
    }

    // ─────────────────────────── views ───────────────────────────

    /// @notice Pending reward for a tokenId, in token wei. Returns 0 if asleep
    ///         or never registered.
    function pendingReward(uint256 tokenId) public view returns (uint256) {
        if (!_isRegistered(tokenId) || asleep[tokenId]) return 0;
        uint8 tier = NFT.tierIndexOf(tokenId);
        uint256 projected = _projectedAcc(tier);
        return (projected - _indexOf(tokenId, tier)) / ACC_PRECISION;
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
        // Unregistered ids report false rather than "stale since the epoch",
        // so reaper bots stop burning gas on tokens that were never minted.
        if (asleep[tokenId] || !_isRegistered(tokenId)) return false;
        return block.timestamp >= _activityAt(tokenId) + SLEEP_THRESHOLD;
    }

    /// @notice Seconds remaining before this tokenId becomes reapable. Returns
    ///         0 if already past the threshold or already asleep.
    function secondsUntilStale(uint256 tokenId) public view returns (uint256) {
        if (asleep[tokenId]) return 0;
        uint256 deadline = _activityAt(tokenId) + SLEEP_THRESHOLD;
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
        if (!_isRegistered(tokenId)) revert NotRegistered();
        if (NFT.ownerOf(tokenId) != user) revert NotNFTOwner();
        if (asleep[tokenId]) revert NFTAsleep();
        _sync();
        uint8 tier = NFT.tierIndexOf(tokenId);
        uint256 owed = (accRewardPerSlot[tier] - _indexOf(tokenId, tier)) / ACC_PRECISION;
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
            if (!_isRegistered(id)) revert NotRegistered();
            if (NFT.ownerOf(id) != user) revert NotNFTOwner();
            if (asleep[id]) revert NFTAsleep();
            uint8 tier = NFT.tierIndexOf(id);
            uint256 owed = (accRewardPerSlot[tier] - _indexOf(id, tier)) / ACC_PRECISION;
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
    /// @dev    `nonReentrant` matters here even though this function moves no
    ///         tokens. Payout paths decrement `lastBalance` and only then call
    ///         `safeTransfer`. A reward token that calls back BEFORE its own
    ///         balance update (ERC777 `tokensToSend`, callback wrappers) could
    ///         otherwise re-enter here, where the contract still holds the
    ///         outgoing amount but has already written it off — and `_sync`
    ///         would book the contract's own payout as fresh rewards. That
    ///         leaves `lastBalance` permanently above the real balance, which
    ///         strands the difference forever: there is no admin to correct it.
    function sync() external nonReentrant {
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
        if (!_isRegistered(tokenId)) revert NotRegistered();
        if (asleep[tokenId]) revert NFTAsleep();
        if (block.timestamp < _activityAt(tokenId) + SLEEP_THRESHOLD) revert NotStaleYet();
        _sync();
        uint8 tier = NFT.tierIndexOf(tokenId);
        uint256 owed = (accRewardPerSlot[tier] - _indexOf(tokenId, tier)) / ACC_PRECISION;
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
        if (!_isRegistered(tokenId)) revert NotRegistered();
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

    /**
     * @notice Called by the NFT contract right after a batch mint.
     *
     * @dev Writes a fixed amount of storage per BATCH rather than per token.
     *      The tokens in a batch share a mint timestamp and a starting reward
     *      index, so those are snapshotted once and derived on read; tier
     *      counts are tallied in memory and applied with five writes at the
     *      end. What remains per token is one `tierIndexOf` read.
     *
     *      Requires the batch to be a contiguous ascending id range, which is
     *      what every OposNFT mint path produces (ids come from a counter).
     *      Enforcing it is what makes the range-based lookups sound.
     */
    function onMintBatch(uint256[] calldata tokenIds) external {
        if (msg.sender != address(NFT)) revert NotNFT();
        _sync();

        uint256 len = tokenIds.length;
        if (len == 0) return;

        uint256 firstId = tokenIds[0];
        uint256 lastId = tokenIds[len - 1];
        if (lastId < firstId || lastId - firstId + 1 != len) revert NonContiguousBatch();
        if (lastId > type(uint32).max) revert NonContiguousBatch();

        uint256[5] memory countsBefore = [
            activeInTier[0], activeInTier[1], activeInTier[2],
            activeInTier[3], activeInTier[4]
        ];

        // Tally tiers in memory — no per-token storage.
        uint256[5] memory added;
        for (uint256 i; i < len; ++i) {
            unchecked { added[NFT.tierIndexOf(tokenIds[i])] += 1; }
        }

        // Snapshot BEFORE the pending release below, so the first minters into
        // an empty tier still collect that tier's backlog.
        uint256 batchIndex = mintBatches.length;
        mintBatches.push(MintBatch({
            firstId: uint32(firstId),
            lastId: uint32(lastId),
            mintedAt: uint48(block.timestamp)
        }));
        for (uint8 t; t < TIERS; ++t) {
            // Zero is the implicit default, so only non-zero snapshots cost gas.
            if (accRewardPerSlot[t] != 0) batchAcc[batchIndex][t] = accRewardPerSlot[t];
        }

        for (uint8 t; t < TIERS; ++t) {
            if (added[t] != 0) {
                unchecked { activeInTier[t] += added[t]; }
            }
        }

        emit TierMintBatch(firstId, lastId, added);

        // Release pending for tiers that went from 0 -> N>0 in this batch.
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
