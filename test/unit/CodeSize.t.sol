// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";
import {console} from "forge-std/console.sol";

/// @notice EIP-170 caps deployed runtime bytecode at 24,576 bytes. Foundry's
///         test EVM does NOT enforce it, so a contract can pass every other
///         test in this repo and still be impossible to deploy to mainnet —
///         which is exactly what happened to OposRenderer (it reached 39KB
///         before the palette/parts split).
///
///         These tests fail the build instead of letting that recur.
contract CodeSizeTest is TestBase {
    /// @dev EIP-170 limit.
    uint256 constant MAX_RUNTIME = 24_576;

    function _assertFits(address target, string memory name) internal view {
        uint256 size = target.code.length;
        assertGt(size, 0, string.concat(name, " has no code"));
        assertLe(
            size,
            MAX_RUNTIME,
            string.concat(name, " exceeds the EIP-170 limit and cannot be deployed")
        );
    }

    function test_C1_all_contracts_are_deployable() public view {
        _assertFits(address(nft), "OposNFT");
        _assertFits(address(distributor), "NFTRewardDistributor");
        _assertFits(address(renderer), "OposRenderer");
        _assertFits(address(renderer.PALETTE()), "OposPalette");
        _assertFits(address(renderer.PARTS()), "OposParts");
    }

    /// @notice Prints remaining headroom per contract. Not an assertion — a
    ///         budget readout for whoever is about to add art.
    ///         Run with: forge test --match-test test_C2 -vv
    function test_C2_report_headroom() public view {
        _report("OposNFT", address(nft));
        _report("NFTRewardDistributor", address(distributor));
        _report("OposRenderer", address(renderer));
        _report("OposPalette", address(renderer.PALETTE()));
        _report("OposParts", address(renderer.PARTS()));
    }

    function _report(string memory name, address target) internal view {
        // solhint-disable-next-line no-console
        console.log(
            string.concat(
                name, ": ", vm.toString(target.code.length),
                " bytes, ", vm.toString(MAX_RUNTIME - target.code.length), " free"
            )
        );
    }
}
