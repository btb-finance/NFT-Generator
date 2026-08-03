// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {OposRenderer} from "../../src/OposRenderer.sol";
import {OposPalette} from "../../src/OposPalette.sol";
import {OposParts} from "../../src/OposParts.sol";

/// @notice The renderer is split across three contracts to stay inside the
///         EIP-170 byte limit, so standing one up takes three deployments.
///         This keeps that detail in one place instead of in every test.
library DeployRenderer {
    function deploy() internal returns (OposRenderer) {
        return new OposRenderer(address(new OposPalette()), address(new OposParts()));
    }
}
