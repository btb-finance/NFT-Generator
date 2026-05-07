// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {OposRenderer} from "../../src/OposRenderer.sol";

/// @notice Property fuzz for the renderer (R1–R4 in FUZZING.md).
contract RendererFuzzTest is Test {
    OposRenderer internal renderer;

    function setUp() public {
        renderer = new OposRenderer();
    }

    // ─────────────────────────── R1 — purity / determinism ────────────────────────

    function testFuzz_R1_determinism(uint256 seed) public view {
        string memory a = renderer.buildArt(seed);
        string memory b = renderer.buildArt(seed);
        assertEq(keccak256(bytes(a)), keccak256(bytes(b)), "same seed -> same SVG");
    }

    // ─────────────────────────── R2 — always valid SVG ────────────────────────────

    function testFuzz_R2_valid_svg(uint256 seed) public view {
        string memory svg = renderer.buildArt(seed);
        bytes memory svgBytes = bytes(svg);
        assertGt(svgBytes.length, 100, "svg should be substantial");

        // Starts with '<svg '
        assertEq(svgBytes[0], bytes1("<"), "starts with <");
        assertEq(svgBytes[1], bytes1("s"), "<s");
        assertEq(svgBytes[2], bytes1("v"), "<sv");
        assertEq(svgBytes[3], bytes1("g"), "<svg");
        assertEq(svgBytes[4], bytes1(" "), "<svg ");

        // Ends with '</svg>'
        uint256 n = svgBytes.length;
        assertEq(svgBytes[n - 6], bytes1("<"), "</");
        assertEq(svgBytes[n - 5], bytes1("/"), "</");
        assertEq(svgBytes[n - 4], bytes1("s"), "</s");
        assertEq(svgBytes[n - 3], bytes1("v"), "</sv");
        assertEq(svgBytes[n - 2], bytes1("g"), "</svg");
        assertEq(svgBytes[n - 1], bytes1(">"), "</svg>");
    }

    // ─────────────────────────── R3 — extreme seeds don't panic ───────────────────

    function test_R3_extreme_seeds() public view {
        renderer.buildArt(0);
        renderer.buildArt(type(uint256).max);
        renderer.buildArt(1);
        renderer.buildArt(2 ** 255);
    }

    // ─────────────────────────── R4 — body color appears in output ────────────────

    function testFuzz_R4_body_color_present(uint256 seed) public view {
        string memory svg = renderer.buildArt(seed);
        // Body color is always emitted at least once. Just sanity-check that
        // the SVG contains at least one fill="#" pattern (any color).
        assertTrue(_containsSubstring(bytes(svg), bytes("fill=\"#")), "should have at least one hex fill");
    }

    // ─────────────────────────── helper ───────────────────────────────────────────

    function _containsSubstring(bytes memory haystack, bytes memory needle) internal pure returns (bool) {
        if (needle.length > haystack.length) return false;
        for (uint256 i = 0; i <= haystack.length - needle.length; ++i) {
            bool match_ = true;
            for (uint256 j = 0; j < needle.length; ++j) {
                if (haystack[i + j] != needle[j]) { match_ = false; break; }
            }
            if (match_) return true;
        }
        return false;
    }
}
