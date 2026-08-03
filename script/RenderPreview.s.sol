// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script} from "forge-std/Script.sol";
import {OposRenderer} from "../src/OposRenderer.sol";
import {OposPalette} from "../src/OposPalette.sol";
import {OposParts} from "../src/OposParts.sol";

/// @notice Run with `forge script script/RenderPreview.s.sol -vvv`
///         to dump three sample SVGs to ./preview_*.svg for visual inspection.
contract RenderPreview is Script {
    function run() external {
        OposRenderer r = new OposRenderer(address(new OposPalette()), address(new OposParts()));
        // Three different seeds to sanity-check trait variation.
        uint256[3] memory seeds = [
            uint256(0xd83393f3d96d10cbde39ba64d2ff2a0acad86a231df52f1745710b8134814961), // user-flagged Astronaut Helmet
            uint256(123456789),
            uint256(0xDEADBEEFCAFEBABE)
        ];
        for (uint256 i; i < seeds.length; i++) {
            string memory svg = r.buildArt(seeds[i]);
            string memory path = string.concat("./preview_", vm.toString(i), ".svg");
            vm.writeFile(path, svg);
        }
    }
}
