// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script} from "forge-std/Script.sol";
import {OposRenderer} from "../src/OposRenderer.sol";

/// @notice Dumps a controlled QA gallery of SVGs to ./gallery/*.svg.
///         Run with: forge script script/RenderGallery.s.sol
///         Then build the viewer with scripts/build_gallery.sh (or see README note).
///
///         Seed bit layout the renderer reads:
///           body       = seed % 30          (bits 0-7 region, mod 30)
///           expression = (seed >> 8)  % 10
///           pattern    = (seed >> 16) % 10
///           accessory  = (seed >> 24) % 15
///           eye        = (seed >> 32) % 20
///           background = (seed >> 40) % 7
contract RenderGallery is Script {
    OposRenderer r;

    function run() external {
        r = new OposRenderer();

        // The renderer reads each trait as `(seed >> shift) % m`. Because the
        // moduli aren't powers of two, any bits ABOVE a field leak into its
        // result. So to force exactly one trait, we set that field and leave
        // everything above it zero (lower bits don't affect `seed >> shift`).

        // ── 1. Every accessory (shift 24) ──
        string[15] memory accNames = [
            "None", "Crown", "TopHat", "BowTie", "Sunglasses", "Bandana",
            "AstronautHelmet", "PirateEyePatch", "GoldenCrown", "WizardHat",
            "FlowerCrown", "Monocle", "Cape", "Halo", "Headphones"
        ];
        for (uint256 a = 0; a < 15; a++) {
            _dump(string.concat("1acc_", _two(a), "_", accNames[a]), a << 24);
        }

        // ── 2. Every expression (shift 8) ──
        string[10] memory expNames = [
            "Happy", "Sleepy", "Winking", "Surprised", "Grumpy",
            "Loving", "Excited", "Shy", "Curious", "Normal"
        ];
        for (uint256 e = 0; e < 10; e++) {
            _dump(string.concat("2exp_", _two(e), "_", expNames[e]), e << 8);
        }

        // ── 3. Every pattern (shift 16) ──
        string[10] memory patNames = [
            "None", "Striped", "Spotted", "Tuxedo", "Patches",
            "TigerStripes", "Gradient", "Calico", "GalaxySwirl", "Flames"
        ];
        for (uint256 p = 0; p < 10; p++) {
            _dump(string.concat("3pat_", _two(p), "_", patNames[p]), p << 16);
        }

        // ── 4. Every body color (shift 0, mod 30) ──
        for (uint256 b = 0; b < 30; b++) {
            _dump(string.concat("4body_", _two(b)), b);
        }

        // ── 5. Fully random seeds (real-world mix) ──
        for (uint256 i = 0; i < 24; i++) {
            uint256 seed = uint256(keccak256(abi.encode(i, "opossum-gallery")));
            _dump(string.concat("5rand_", _two(i)), seed);
        }

        // ── 6. Every eye color (open "Normal" eyes, no eye-covering accessory) ──
        string[20] memory eyeNames = [
            "Green", "Blue", "Gold", "Pink", "Brown", "Cyan", "Red", "Purple",
            "Amber", "Violet", "Turquoise", "Silver", "Lime", "Indigo", "Orange",
            "Sapphire", "Emerald", "Rainbow", "LaserRed", "CosmicBlue"
        ];
        for (uint256 e = 0; e < 20; e++) {
            _dump(string.concat("6eye_", _two(e), "_", eyeNames[e]), _composeEye(e));
        }
    }

    /// @dev Build a seed whose derived traits are: eye = `eye`, expression = 9
    ///      (Normal, open round eyes so the iris shows), accessory = 0 (None),
    ///      pattern = 0 (None), background = 0. The renderer extracts each trait
    ///      as `(seed >> shift) % m` and higher fields leak into lower ones, so
    ///      we solve each field byte from the top down to cancel that leakage.
    function _composeEye(uint256 eye) internal pure returns (uint256) {
        uint256 accField = (0 + 15 - ((eye * 256) % 15)) % 15;                 // accessory -> 0
        uint256 patField = (0 + 10 - ((accField * 256 + eye * 65536) % 10)) % 10; // pattern -> 0
        uint256 exprR = (patField * 256 + accField * 65536 + eye * 16777216) % 10;
        uint256 exprField = (9 + 10 - exprR) % 10;                             // expression -> 9
        return (eye << 32) | (accField << 24) | (patField << 16) | (exprField << 8);
    }

    function _dump(string memory label, uint256 seed) internal {
        string memory svg = r.buildArt(seed);
        vm.writeFile(string.concat("./gallery/", label, ".svg"), svg);
    }

    function _two(uint256 n) internal pure returns (string memory) {
        if (n < 10) return string.concat("0", vm.toString(n));
        return vm.toString(n);
    }
}
