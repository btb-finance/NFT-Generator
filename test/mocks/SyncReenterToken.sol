// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ISync {
    function sync() external;
}

/// @notice Adversarial ERC20 that re-enters `sync()` BEFORE its own balance
///         update lands.
///
///         ReentrantToken re-enters after `super._update`, by which point the
///         distributor's balance has already dropped and `sync()` is a no-op.
///         The untested case is a token whose hook fires first — an ERC777
///         `tokensToSend`, a fee-on-transfer wrapper, or any callback token.
///         Then `sync()` sees a balance that still includes the outbound
///         payment while `lastBalance` has already been decremented, which
///         would make the distributor count its own payout as fresh rewards.
///
///         `sync()` is the one state-changing entry point without
///         `nonReentrant`, so it is the only way in.
contract SyncReenterToken is ERC20 {
    address public target;
    bool public armed;

    constructor() ERC20("Sync Reenter", "SRNT") {}

    function mintTo(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function arm(address distributor) external {
        target = distributor;
        armed = true;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (armed && from == target) {
            armed = false; // one shot
            ISync(target).sync();
        }
        super._update(from, to, value);
    }
}
