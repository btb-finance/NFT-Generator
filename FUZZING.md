# Fuzzing & Invariant Specification

> **Read this first.** This document defines the properties the contracts MUST hold under any input. When a fuzz/invariant test fails, **the contract is wrong, not the test**. Do not edit a test to make it pass — fix the bug or change the spec deliberately and explicitly here first.

The repo has three production contracts under test plus one external dependency:

| Contract | Type | What's at stake |
|---|---|---|
| `OposNFT.sol` | ERC-721 | Mint accounting, tier assignment, distributor notification |
| `NFTRewardDistributor.sol` | Custodial | OPOS rewards, claim correctness, sleep/reap economics |
| `OposRenderer.sol` | Pure | SVG output validity & determinism |
| `OPOSSUM` (already deployed) | ERC-20 | Tax routing — out of scope here, but its behavior is assumed |

---

## Scope of fuzzing

Three layers of automated checking, in order of value:

1. **Stateful invariants** (Foundry `forge test --match-contract Invariant`) — random sequences of calls; assertions hold after every call.
2. **Stateless property fuzz** (Foundry `function testFuzz_*` with `vm.assume`) — random inputs to one function; output property holds.
3. **Unit edge cases** — explicit boundary tests for documented thresholds (0, 1, MAX_SUPPLY, MAX_SUPPLY+1, sleep threshold ± 1 second).

For invariant tests, configure handlers to call the full external surface with weighted randomness. Restrict actor pool (≥ 5 EOAs) so handler senders rotate.

---

## Global invariants (must hold across every state transition)

These are non-negotiable. Any sequence of admin/user calls — mints, claims, transfers, reaps, wakes, fees — must leave the system satisfying:

### G1 — Solvency
```
distributor.balance(OPOS) >= sum(lastBalance unclaimed) + sum(tierPending[t] for t in 0..4)
```
The contract never owes more than it holds. If the OPOS balance drops below the sum of all claimable + pending, something stole funds.

### G2 — Conservation of fees
```
total_OPOS_received_by_distributor 
  = sum(lifetimeClaimed[id] for all minted ids) 
  + sum(pendingReward(id) for all minted ids) 
  + sum(tierPending[t] for t in 0..4) 
  + dust
```
Where `dust ≤ 5 wei × number_of_syncs` (rounding from 5-way `% 5` split). No fees vanish, no fees are double-counted.

### G3 — No double-claim
For any tokenId and any sequence:
```
total claimed against tokenId == lifetimeClaimed[tokenId]
```
Calling `claim(id)` twice in a row, second call returns 0 OPOS.

### G4 — Last-index monotonicity
For any tokenId, across the lifetime of the contract:
```
lastIndex[id]_after >= lastIndex[id]_before  (always)
```
Resets are forbidden. Set-once-equal-to-current is the only allowed write pattern.

### G5 — Active count integrity
For each tier `t ∈ 0..4`:
```
activeInTier[t] == count(minted_ids_in_tier_t where !asleep[id])
```
Must hold after mint, transfer, reap, wake. Off-by-one here is a critical bug.

### G6 — Sleep/awake mutual exclusion
An asleep NFT is excluded from the active divisor. A waking NFT is added to it. Reaping increments by 0, decrements by 1; waking does the inverse. A mint that lands on an asleep NFT is impossible (can't sleep before mint). Reentrancy must not double-flip.

### G7 — Tier purity
```
For all tokenId minted: NFT.tierIndexOf(id) is deterministic and stable.
                        Calling it 1000 times returns the same value.
```
Tier is derived from `tokenTraits[id]` which is set once at mint and never written again.

---

## `OposNFT.sol` properties

### N1 — Token ID monotonicity & uniqueness
- `_tokenIdCounter` only increases.
- `_safeMint` is called exactly once per ID.
- No tokenId > `MAX_SUPPLY` is ever minted.
- Property: `for any minted id, 1 ≤ id ≤ MAX_SUPPLY`.

### N2 — Mint paths cap at MAX_SUPPLY
```
adminMint(amount)         → reverts if _tokenIdCounter + amount > MAX_SUPPLY
buy(amount)               → same
giftNFT(recipients)       → reverts if _tokenIdCounter + recipients.length > MAX_SUPPLY
```
Fuzz: random combinations of admin/buy/gift up to and past MAX_SUPPLY must revert at the boundary, never succeed past it.

### N3 — Mint payment correctness (`buy`)
- Reverts if `msg.value < mintPrice * amount`.
- Refunds exactly `msg.value - mintPrice * amount` when overpaid.
- Property: `buyer_eth_balance_after = buyer_eth_balance_before - (mintPrice * amount) - gas`.

### N4 — Distributor notification
After every successful mint path (admin, buy, gift), the corresponding `onMintBatch(ids)` call must have happened with the exact ids minted in that call — IF distributor is wired. If distributor is unset, no call is attempted (no revert).

Fuzz: assert `distributor.activeInTier` increments match the actual tier counts of minted ids.

### N5 — Owner-only enforcement
`adminMint`, `giftNFT`, `setMintPrice`, `setRenderer`, `setDistributor`, `setDefaultRoyalty`, `withdraw` — every one must revert when called by a non-owner. Fuzz the caller address with `vm.assume(caller != owner)`.

### N6 — Royalty consistency
```
royaltyInfo(tokenId, salePrice) returns (receiver, royalty)
royalty / salePrice == 0.05 (within rounding)
```
After `setDefaultRoyalty(receiver, feeNumerator)`, the receiver field matches and the rate matches `feeNumerator / 10000`.

### N7 — Withdraw
- Only owner.
- Sends entire ETH balance to owner.
- Reverts if balance is zero.
- Property: post-call `address(this).balance == 0` AND `owner.balance == prev + balance`.

### N8 — `tierIndexOf` access guard
- Reverts on non-existent token.
- Returns value in `[0, 4]` for any minted token.

### N9 — `tokenURI` validity
- Always returns a non-empty string.
- Always starts with `"data:application/json;base64,"`.
- Decoded JSON has the required keys: `name`, `description`, `image`, `attributes`.
- `attributes` array length is exactly 11 (8 trait + 3 yield/status).
- `image` decodes to valid SVG starting with `<svg`.

### N10 — `giftNFT` inputs
- Reverts on empty array.
- Reverts on >500 recipients.
- Reverts if any recipient is `address(0)`.
- Each recipient receives exactly 1 NFT.
- Sum of `Transfer(0x0, recipient, _)` events equals `recipients.length`.

---

## `NFTRewardDistributor.sol` properties

### D1 — `_sync` correctness
Given a fee `F` arrives at the distributor between two syncs:
```
After _sync():
  newRewards    = F
  lastBalance   += F
  for each tier t with activeInTier[t] > 0:
    accRewardPerSlot[t] += (F * 0.20 * PRECISION) / activeInTier[t]
  for each tier t with activeInTier[t] == 0:
    tierPending[t] += F * 0.20
```
Sum of distributed + pending = `F` (modulo `5 wei` dust).

### D2 — `claim` correctness
For token `id` in tier `t`, awake, owned by caller:
```
owed = (accRewardPerSlot[t] - lastIndex[id]) / PRECISION

After claim(id):
  REWARD_TOKEN.balanceOf(caller) += owed
  REWARD_TOKEN.balanceOf(distributor) -= owed
  lastIndex[id] = accRewardPerSlot[t]
  lifetimeClaimed[id] += owed
  lastActivityAt[id]  = block.timestamp
  lastBalance         -= owed
```
A second immediate claim returns 0.

### D3 — `claimMany` matches `claim` per-id
For any list of owned-awake ids, calling `claimMany([ids])` produces the same final state as iterating `claim(id)` over each id (modulo gas). No id earns differently when batched.

### D4 — Reentrancy guard holds
A malicious ERC-20 reward token (or callback mid-transfer) cannot re-enter `claim`, `claimMany`, `reap`, `wake`, or `sync`. Test with a mock token that re-enters in `transfer`. All re-entries must revert.

### D5 — `reap` eligibility
```
reap(id) reverts unless:
  asleep[id] == false AND
  block.timestamp >= lastActivityAt[id] + SLEEP_THRESHOLD
```
Fuzz with `block.timestamp` warped just below threshold (must revert) and just at threshold (must succeed).

### D6 — `reap` payout & state
After `reap(id)`:
- Reaper receives the full pending reward (=100%).
- `asleep[id] = true`.
- `activeInTier[tier] -= 1` (saturating at 0).
- `lifetimeClaimed[id]` increases by the reaped amount.
- `lastIndex[id]` snapped to current `accRewardPerSlot[tier]`.
- `lastActivityAt[id]` does NOT change (so a re-mint to wake doesn't preserve old activity).

### D7 — `wake` access & state
```
wake(id) reverts unless:
  msg.sender == NFT.ownerOf(id) AND
  asleep[id] == true
```
After wake:
- `asleep[id] = false`.
- `activeInTier[tier] += 1`.
- `lastActivityAt[id] = block.timestamp`.
- `lastIndex[id] = accRewardPerSlot[tier]` (NEW value, post-sync).
- If tier transitioned `0 → 1` AND `tierPending[tier] > 0`: pending released, `tierPending[tier] = 0`, `accRewardPerSlot[tier]` increases accordingly.

### D8 — Wake does not retroactively pay
Sequence: NFT minted → fees flow → reaped → more fees flow → woken.
The woken NFT's first claim after wake must equal **only** the rewards from `wake_time` onwards. None of the during-sleep growth.

### D9 — `onMintBatch` access
Only callable by `address(NFT)`. Random EOAs and contracts must revert with `NotNFT`.

### D10 — `onMintBatch` semantics
After `onMintBatch([id1..idN])`:
- For each id: `lastIndex[id] = accRewardPerSlot[NFT.tierIndexOf(id)]` (pre-pending-release value).
- For each id: `lastActivityAt[id] = block.timestamp`.
- For each id: `activeInTier[tier] += 1`.
- For each tier that went from `0 → ≥1` in this batch, AND `tierPending[t] > 0`: pending released to those new minters.

### D11 — Tier-pending release fairness
If a tier was empty and 5 NFTs in that tier mint in one batch with `tierPending[t] = X`:
- After the batch, accumulated index increment = `X * PRECISION / 5`.
- Each of the 5 new NFTs can claim `X / 5` (modulo precision dust).

### D12 — Solvency under adversarial fee patterns
Fuzz with random fee arrival sizes (including 0 and 1 wei), random claim/reap/wake/mint sequences, and random `block.timestamp` warps. After each step, G1 must hold.

### D13 — Empty-tier behavior
If `activeInTier[t] == 0` for any duration and fees arrive:
- Per-fee, exactly `20%` of that fee is added to `tierPending[t]`.
- No silent loss.
- When the next NFT mints/wakes into that tier, the entire `tierPending[t]` is released to it (or split among the batch).

### D14 — `pendingReward` returns 0 for asleep
`pendingReward(id) == 0` whenever `asleep[id] == true`. Holds even if `accRewardPerSlot[tier] > lastIndex[id]`.

### D15 — `_projectedAcc` matches `_sync` outcome
For any state, calling `pendingReward(id)` then `sync()` then re-reading the storage must yield the same total claimable. The projection used by view functions cannot lie.

### D16 — Yield-multiplier monotonicity
`yieldMultiplier(rareTier)` is non-decreasing as common-tier active count grows and the rare-tier active count stays constant. Symmetric: it's non-increasing as rare-tier count grows.

---

## `OposRenderer.sol` properties

### R1 — Purity / determinism
`buildArt(seed)` is `pure`. Calling with the same seed returns byte-for-byte identical output, every time, across blocks.

### R2 — Always valid SVG
Output starts with `<svg ` and ends with `</svg>`. Length > 100 bytes. No null bytes.

### R3 — Trait coverage
For any seed, no panics across all branches:
- 30 body colors, 20 eye colors, 10 expressions, 10 patterns, 15 accessories, 7 backgrounds.
- Fuzz seeds `0`, `type(uint256).max`, and 1024 random uint256s. None must revert or produce empty output.

### R4 — Color emission sanity
For every body / eye / accessory branch, the corresponding hex color string appears in the SVG output. Verify by substring search.

---

## Cross-contract invariants

### X1 — NFT count vs distributor active count
At any point:
```
sum(activeInTier) + sum(asleep_count_per_tier) == totalSupply()
```
where `asleep_count_per_tier[t] = count of minted ids where tierIndexOf(id) == t AND asleep[id] == true`.

### X2 — Mint-time tier match
For any minted id:
```
distributor.activeInTier[NFT.tierIndexOf(id)] increased by 1 in the mint tx
```
Verified by checking pre/post counts in invariant handlers.

### X3 — Distributor solvency vs minted set
For all minted ids:
```
sum(distributor.lifetimeClaimed[id] + distributor.pendingReward(id)) + sum(tierPending[t])
  ≤ total_OPOS_ever_received_by_distributor
```
The distributor never owes more than it received.

### X4 — Transfer carries unclaimed
After `nft.transferFrom(A, B, id)` (no claim in between):
- `pendingReward(id)` is unchanged.
- `lastIndex[id]` is unchanged.
- A subsequent `claim(id)` from B receives the pre-transfer pending.

### X5 — No phantom tokens
For each `id` reported by `Transfer(0x0, _, id)`: `_tokenIdCounter > id` always.

---

## Adversarial scenarios to script as fuzz handlers

These are concrete attack shapes the invariant suite must exercise. None should be able to break G1–G7.

| # | Scenario | Expected outcome |
|---|---|---|
| A1 | Reentrant ERC-20 inside `claim` | Revert via `nonReentrant`; state unchanged |
| A2 | Double-claim same block | Second call returns 0, no state change beyond no-op |
| A3 | Reap own NFT | Allowed; reaper (= owner) takes pending; NFT goes asleep |
| A4 | Wake then immediate reap | `reap` reverts (`NotStaleYet`) — wake reset the timer |
| A5 | Reap before threshold | Revert `NotStaleYet` |
| A6 | Mint into empty tier with `tierPending > 0` | First minter inherits backlog; sum unchanged |
| A7 | Sandwiched fee + claim | Claim sees fee post-`_sync`; nothing lost |
| A8 | `onMintBatch` from non-NFT caller | Revert `NotNFT` |
| A9 | `setDistributor(0)` then mint | Mint succeeds; no notification attempted; distributor state untouched |
| A10 | All NFTs in tier reaped | `tierPending[t]` accumulates new fees; first wake/mint releases backlog |
| A11 | Sleep threshold ± 1 second boundary | Inclusive at threshold; reverts 1s before |
| A12 | Mint to address(0) via `giftNFT` | Revert `Zero recipient` |
| A13 | Buy with zero value at zero `mintPrice` | Allowed; refund works at zero |
| A14 | Mint MAX_SUPPLY in one batch | Allowed; subsequent mints all revert |
| A15 | Owner withdraws while mint is in flight | No fund loss; mint completes or reverts atomically |
| A16 | Token receiver is a contract that always reverts on `_safeMint` callback | Mint reverts; `_tokenIdCounter` rolled back implicitly (atomic tx) |

---

## Test framework conventions

- **Foundry** `forge test`. Use `--ffi` only if absolutely needed (prefer not).
- Invariant tests live under `test/invariant/`. Property tests under `test/fuzz/`. Unit tests under `test/unit/`.
- Each invariant test contract must:
  - Set up the full system: deploy renderer, NFT, distributor; wire `setDistributor`.
  - Deploy a mock OPOS (simple ERC-20) and use `mintFor` helpers to send fees to the distributor at random rates.
  - Use a `Handler` contract with bounded-randomness functions covering: `mint`, `gift`, `buy`, `claim`, `reap`, `wake`, `sync`, `transferNFT`, `feeArrives`, `warpTime`.
  - Register handlers via `targetContract` / `targetSelector`.
  - Assert all G* and X* invariants in `invariant_*` functions.
- Use `bound(input, low, high)` rather than `vm.assume` for input shaping when iterating many fuzz runs — better corpus.
- Set `runs = 5000`, `depth = 50` minimum for invariant runs in CI; locally `runs = 50000` for nightly.

## What to do when a fuzz fails

1. Reproduce: copy the failing call sequence Foundry prints to a deterministic unit test under `test/unit/regression/`.
2. Diagnose. Do not edit the invariant. Do not edit the test.
3. If the contract is wrong → fix the contract. Add a regression test referencing this doc's section (e.g., `// FUZZING.md G2 — fix sum-loss in pending release`).
4. If the spec is wrong → first edit this document, get sign-off, then update the test. The contract change comes after.
5. Re-run the full invariant suite, not just the failing one — fixes can shift state in unexpected ways.

## Known carve-outs (not bugs)

- **Up to ~5 wei dust per `_sync`** from the 5-way `% 5` split is acceptable and stays in the contract.
- **First-minter / first-waker windfall** for empty tiers is intentional (G2 still holds because the windfall counts toward `lifetimeClaimed`).
- **Active-tier count saturating at 0 in `reap`** (defensive `if > 0`) is intentional even though G5 should already prevent underflow — belt-and-suspenders.
- **`lastActivityAt` not reset on transfer** is by design; the buyer of a stale NFT can lose to a reaper. Document in dApp UI; do not "fix" with a transfer hook unless you change the spec here first.
