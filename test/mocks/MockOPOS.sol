// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Plain ERC20 used to simulate OPOS in tests. The distributor
///         uses balance-diffing, so it doesn't care about the source token's
///         tax behavior. Using a plain mock keeps the distributor logic under
///         test in isolation. Use `mintTo(distributor, X)` to simulate
///         "X OPOS of fees just arrived".
contract MockOPOS is ERC20 {
    constructor() ERC20("Mock OPOS", "mOPOS") {}

    function mintTo(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
