// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IDistributorAttack {
    function claim(uint256 tokenId) external;
    function reap(uint256 tokenId) external;
}

/// @notice Adversarial ERC20: re-enters the distributor inside `transfer`.
///         Used to verify `nonReentrant` blocks the second call.
///
///         Set `attackTarget` and `attackTokenId` then trigger any path that
///         calls `transfer(...)` (i.e., `claim`/`reap`). On transfer this
///         token tries to re-enter the same distributor with `claim` or
///         `reap` — both must revert.
contract ReentrantToken is ERC20 {
    address public attackTarget;
    uint256 public attackTokenId;
    bool public attackEnabled;
    bytes public lastRevertData;

    enum Mode { Claim, Reap }
    Mode public mode = Mode.Claim;

    constructor() ERC20("Reentrant Token", "REENT") {}

    function mintTo(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setAttack(address target, uint256 tokenId, bool enabled, Mode m) external {
        attackTarget = target;
        attackTokenId = tokenId;
        attackEnabled = enabled;
        mode = m;
    }

    /// @dev Override the internal `_update` (which ERC20 transfers route through)
    ///      to re-enter the distributor. If the re-entry succeeds, we've broken
    ///      the guard; if it reverts, we capture the revert data so the test can
    ///      assert it failed for the right reason.
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (attackEnabled && from != address(0) && to != address(0)) {
            // Disable to avoid infinite loop if guard somehow lets us through.
            attackEnabled = false;
            if (mode == Mode.Claim) {
                try IDistributorAttack(attackTarget).claim(attackTokenId) {
                    // Should NEVER reach here.
                    revert("REENTRANCY-SUCCEEDED");
                } catch (bytes memory data) {
                    lastRevertData = data;
                }
            } else {
                try IDistributorAttack(attackTarget).reap(attackTokenId) {
                    revert("REENTRANCY-SUCCEEDED");
                } catch (bytes memory data) {
                    lastRevertData = data;
                }
            }
        }
    }
}
