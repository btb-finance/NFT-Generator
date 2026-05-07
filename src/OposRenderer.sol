// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title OposRenderer
 * @dev Pure-function on-chain SVG renderer for the OPOSSUM NFT collection.
 *      24x24 pixel grid scaled to 480x480; each "pixel" is a 20x20 SVG rect.
 *      Trait selection (body color, eye color, expression, pattern, accessory,
 *      background) is derived from the seed in the same bit ranges the NFT
 *      contract uses for trait names, so visual + textual traits stay in sync.
 */
contract OposRenderer {
    using Strings for uint256;

    /// @notice Build the complete on-chain SVG for a tokenId given its trait seed.
    function buildArt(uint256 seed) external pure returns (string memory) {
        string memory pixels = _drawOpossum(seed);
        string memory bgColor = _getBackground(seed);

        return string(abi.encodePacked(
            '<svg width="480" height="480" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">',
            '<rect width="480" height="480" fill="', bgColor, '"/>',
            pixels,
            '</svg>'
        ));
    }

    function _getBackground(uint256 seed) private pure returns (string memory) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 bgIndex = uint8((seed >> 40) % 7);
        if (bgIndex == 0) return "#87CEEB";  // Sky Blue
        if (bgIndex == 1) return "#FFB6C1";  // Pink Dream
        if (bgIndex == 2) return "#228B22";  // Forest Green
        if (bgIndex == 3) return "#191970";  // Night Sky
        if (bgIndex == 4) return "#9B59B6";  // Purple Nebula
        if (bgIndex == 5) return "#FFA500";  // Sunset Orange
        return "#FF69B4";                     // Hot Pink
    }

    /**
     * @dev Draws a front-facing opossum: rounded head with pointy ears (pink inner),
     *      white face mask narrowing to a triangular snout, pink nose at the tip,
     *      a chunky body with lighter belly, pink feet, and a long curving tail.
     */
    function _drawOpossum(uint256 seed) private pure returns (string memory) {
        string memory bodyColor = _getBodyColor(seed);
        string memory shade = _adjustBrightness(bodyColor, -30);
        string memory eyeColor = _getEyeColor(seed);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 expression = uint8((seed >> 8) % 10);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 pattern = uint8((seed >> 16) % 10);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 accessory = uint8((seed >> 24) % 15);

        string memory out = "";

        // ── Pointy ears with pink inner ──
        out = string(abi.encodePacked(out,
            _pixel(7, 2, "#000"), _pixel(8, 2, "#000"),
            _pixel(7, 3, "#000"), _pixel(8, 3, "#FFC0CB"),
            _pixel(7, 4, "#000"), _pixel(8, 4, "#FFC0CB"),
            _pixel(15, 2, "#000"), _pixel(16, 2, "#000"),
            _pixel(15, 3, "#FFC0CB"), _pixel(16, 3, "#000"),
            _pixel(15, 4, "#FFC0CB"), _pixel(16, 4, "#000")
        ));

        // ── Head outline (trapezoidal: wide top, narrowing to snout) ──
        out = string(abi.encodePacked(out,
            _rect(6, 4, 12, 1, "#000"),    // top edge
            _rect(6, 4, 1, 5, "#000"),     // upper-left side
            _rect(17, 4, 1, 5, "#000"),    // upper-right side
            _pixel(7, 9, "#000"),  _pixel(16, 9, "#000"),
            _pixel(8, 10, "#000"), _pixel(15, 10, "#000"),
            _pixel(9, 11, "#000"), _pixel(14, 11, "#000"),
            _pixel(10, 12, "#000"), _pixel(13, 12, "#000")
        ));

        // ── Head fill (body color) ──
        out = string(abi.encodePacked(out,
            _rect(7, 4, 10, 5, bodyColor),
            _rect(8, 9, 8, 1, bodyColor),
            _rect(9, 10, 6, 1, bodyColor),
            _rect(10, 11, 4, 1, bodyColor)
        ));

        // ── White face mask (the iconic opossum look) ──
        out = string(abi.encodePacked(out,
            _rect(8, 6, 8, 3, "#FFFFFF"),
            _rect(9, 9, 6, 1, "#FFFFFF"),
            _rect(10, 10, 4, 1, "#FFFFFF"),
            _rect(11, 11, 2, 1, "#FFFFFF")
        ));

        // ── Pink nose at snout tip ──
        out = string(abi.encodePacked(out,
            _pixel(11, 12, "#FF1493"),
            _pixel(12, 12, "#FF1493")
        ));

        // ── Eyes (driven by expression) ──
        out = string(abi.encodePacked(out, _drawEyes(expression, eyeColor)));

        // ── Shoulders: wider connector that bridges narrow snout to body ──
        out = string(abi.encodePacked(out,
            _rect(7, 12, 3, 1, bodyColor), _rect(13, 12, 4, 1, bodyColor),
            _pixel(7, 12, "#000"), _pixel(16, 12, "#000")
        ));

        // ── Body outline + fill ──
        out = string(abi.encodePacked(out,
            _rect(5, 13, 14, 1, "#000"),   // top
            _rect(5, 19, 14, 1, "#000"),   // bottom
            _rect(5, 13, 1, 7, "#000"),    // left
            _rect(18, 13, 1, 7, "#000"),   // right
            _rect(6, 14, 12, 5, bodyColor) // fill
        ));

        // ── Lighter belly (the white underside) ──
        out = string(abi.encodePacked(out,
            _rect(8, 15, 8, 3, "#F5F5F5")
        ));

        // ── Pink feet peeking out at the bottom ──
        out = string(abi.encodePacked(out,
            _rect(6, 19, 2, 1, "#FFC0CB"),
            _rect(10, 19, 2, 1, "#FFC0CB"),
            _rect(14, 19, 2, 1, "#FFC0CB"),
            _rect(16, 19, 2, 1, "#FFC0CB")
        ));

        // ── Long curving hairless tail (pink-tipped) ──
        out = string(abi.encodePacked(out,
            _pixel(19, 16, "#000"), _pixel(19, 17, bodyColor), _pixel(19, 18, "#000"),
            _pixel(20, 15, "#000"), _pixel(20, 16, bodyColor),
            _pixel(21, 14, "#000"), _pixel(21, 15, bodyColor),
            _pixel(22, 13, "#000"), _pixel(22, 14, "#FFC0CB"), _pixel(22, 15, "#000")
        ));

        // ── Pattern overlay ──
        out = string(abi.encodePacked(out, _drawPattern(pattern, shade)));

        // ── Accessory overlay ──
        out = string(abi.encodePacked(out, _drawAccessory(accessory, eyeColor)));

        return out;
    }

    function _drawEyes(uint8 expression, string memory eyeColor) private pure returns (string memory) {
        // Eye region: cols 9-10 (left) and 13-14 (right), rows 7-8.
        if (expression == 0) {
            // Happy — closed curves with raised brows
            return string(abi.encodePacked(
                _rect(9, 7, 2, 1, "#000"), _rect(13, 7, 2, 1, "#000"),
                _pixel(9, 6, "#000"), _pixel(14, 6, "#000")
            ));
        } else if (expression == 1) {
            // Sleepy — single line eyes
            return string(abi.encodePacked(
                _rect(9, 8, 2, 1, "#000"),
                _rect(13, 8, 2, 1, "#000")
            ));
        } else if (expression == 2) {
            // Winking — one open, one closed
            return string(abi.encodePacked(
                _rect(9, 7, 2, 2, eyeColor),
                _pixel(9, 7, "#FFFFFF"),
                _rect(13, 8, 2, 1, "#000")
            ));
        } else if (expression == 3) {
            // Surprised — wide round
            return string(abi.encodePacked(
                _rect(9, 7, 2, 2, "#000"),
                _rect(13, 7, 2, 2, "#000"),
                _pixel(9, 7, "#FFFFFF"), _pixel(13, 7, "#FFFFFF")
            ));
        } else if (expression == 4) {
            // Grumpy — angled brows
            return string(abi.encodePacked(
                _rect(9, 8, 2, 1, "#000"),
                _rect(13, 8, 2, 1, "#000"),
                _pixel(8, 6, "#000"), _pixel(10, 7, "#000"),
                _pixel(13, 7, "#000"), _pixel(15, 6, "#000")
            ));
        } else if (expression == 5) {
            // Loving — pink hearts
            return string(abi.encodePacked(
                _pixel(9, 7, "#FF1493"), _pixel(10, 7, "#FF1493"),
                _pixel(13, 7, "#FF1493"), _pixel(14, 7, "#FF1493"),
                _pixel(9, 8, "#FF1493"), _pixel(13, 8, "#FF1493")
            ));
        } else if (expression == 6) {
            // Excited — bright wide eyes
            return string(abi.encodePacked(
                _rect(9, 7, 2, 2, eyeColor),
                _rect(13, 7, 2, 2, eyeColor),
                _pixel(9, 7, "#FFFFFF"), _pixel(13, 7, "#FFFFFF")
            ));
        } else if (expression == 7) {
            // Shy — half-closed
            return string(abi.encodePacked(
                _rect(9, 8, 2, 1, eyeColor),
                _rect(13, 8, 2, 1, eyeColor)
            ));
        } else if (expression == 8) {
            // Curious — one raised brow
            return string(abi.encodePacked(
                _rect(9, 7, 2, 1, "#000"),
                _rect(13, 7, 2, 1, "#000"),
                _pixel(8, 6, "#000"), _pixel(9, 6, "#000")
            ));
        }
        // Normal — small beady eyes
        return string(abi.encodePacked(
            _pixel(9, 7, "#000"), _pixel(10, 7, "#000"),
            _pixel(13, 7, "#000"), _pixel(14, 7, "#000")
        ));
    }

    function _drawPattern(uint8 pattern, string memory shade) private pure returns (string memory) {
        if (pattern == 1) {
            // Striped — vertical bars on the body
            return string(abi.encodePacked(
                _rect(7, 14, 1, 5, shade),
                _rect(10, 14, 1, 5, shade),
                _rect(13, 14, 1, 5, shade),
                _rect(16, 14, 1, 5, shade)
            ));
        } else if (pattern == 2) {
            // Spotted
            return string(abi.encodePacked(
                _pixel(8, 15, shade), _pixel(15, 16, shade),
                _pixel(11, 17, shade), _pixel(13, 14, shade)
            ));
        } else if (pattern == 3) {
            // Tuxedo — vertical white stripe down the middle of the body
            return _rect(11, 14, 2, 5, "#FFFFFF");
        } else if (pattern == 4) {
            // Patches
            return string(abi.encodePacked(
                _rect(7, 14, 3, 2, shade),
                _rect(14, 16, 3, 2, shade)
            ));
        } else if (pattern == 5) {
            // Tiger Stripes — horizontal black bands
            return string(abi.encodePacked(
                _rect(8, 15, 3, 1, "#000"),
                _rect(13, 17, 3, 1, "#000")
            ));
        } else if (pattern == 6) {
            // Gradient — darker bottom band
            return _rect(6, 18, 12, 1, shade);
        } else if (pattern == 7) {
            // Calico — multi-color patches
            return string(abi.encodePacked(
                _rect(7, 14, 3, 2, "#FF8C42"),
                _rect(14, 16, 3, 2, "#2C2C2C"),
                _rect(10, 18, 3, 1, "#FFFFFF")
            ));
        } else if (pattern == 8) {
            // Galaxy Swirl — scattered cosmic specks
            return string(abi.encodePacked(
                _pixel(8, 14, "#9B30FF"), _pixel(11, 15, "#FFFFFF"),
                _pixel(14, 14, "#4B0082"), _pixel(16, 17, "#9B30FF"),
                _pixel(9, 18, "#FFFFFF"), _pixel(13, 16, "#4B0082")
            ));
        } else if (pattern == 9) {
            // Flames — orange/red licks at the bottom of the body
            return string(abi.encodePacked(
                _rect(7, 19, 1, 1, "#FF6347"), _rect(9, 18, 1, 2, "#FF4500"),
                _rect(11, 19, 2, 1, "#FFA500"), _rect(14, 18, 1, 2, "#FF4500"),
                _rect(16, 19, 1, 1, "#FF6347")
            ));
        }
        return "";
    }

    function _drawAccessory(uint8 accessory, string memory eyeColor) private pure returns (string memory) {
        if (accessory == 1) {
            // Crown
            return string(abi.encodePacked(
                _rect(9, 2, 6, 2, "#FFD700"),
                _pixel(10, 1, "#FFD700"), _pixel(12, 1, "#FFD700"), _pixel(14, 1, "#FFD700")
            ));
        } else if (accessory == 2) {
            // Top Hat
            return string(abi.encodePacked(
                _rect(9, 0, 6, 2, "#000"),
                _rect(8, 2, 8, 1, "#000")
            ));
        } else if (accessory == 3) {
            // Bow Tie — sits at the neck
            return string(abi.encodePacked(
                _rect(10, 13, 1, 1, "#FF0000"),
                _rect(13, 13, 1, 1, "#FF0000"),
                _pixel(11, 13, "#FF0000"), _pixel(12, 13, "#FF0000")
            ));
        } else if (accessory == 4) {
            // Sunglasses
            return string(abi.encodePacked(
                _rect(8, 7, 3, 2, "#000"),
                _rect(13, 7, 3, 2, "#000"),
                _rect(11, 7, 2, 1, "#000")
            ));
        } else if (accessory == 5) {
            // Bandana around the head
            return string(abi.encodePacked(
                _rect(7, 4, 10, 1, "#FF0000"),
                _pixel(6, 5, "#FF0000"), _pixel(17, 5, "#FF0000")
            ));
        } else if (accessory == 6) {
            // Astronaut Helmet — silver frame around the head with a glass shine
            // highlight. No fill, so the face stays fully visible underneath.
            return string(abi.encodePacked(
                _rect(6, 3, 12, 1, "#C0C0C0"),
                _rect(5, 4, 1, 9, "#C0C0C0"),
                _rect(18, 4, 1, 9, "#C0C0C0"),
                _pixel(7, 4, "#FFFFFF"),
                _pixel(6, 5, "#FFFFFF")
            ));
        } else if (accessory == 7) {
            // Pirate Eye Patch
            return string(abi.encodePacked(
                _rect(13, 7, 3, 2, "#000"),
                _rect(7, 6, 10, 1, "#000")
            ));
        } else if (accessory == 8) {
            // Golden Crown (fancier)
            return string(abi.encodePacked(
                _rect(8, 1, 8, 3, "#FFD700"),
                _pixel(9, 0, "#FFD700"), _pixel(11, 0, "#FFD700"),
                _pixel(13, 0, "#FFD700"), _pixel(15, 0, "#FFD700")
            ));
        } else if (accessory == 9) {
            // Wizard Hat
            return string(abi.encodePacked(
                _rect(11, 0, 2, 3, "#4B0082"),
                _rect(10, 3, 4, 1, "#4B0082"),
                _pixel(12, 2, "#FFD700")
            ));
        } else if (accessory == 10) {
            // Flower Crown
            return string(abi.encodePacked(
                _pixel(8, 3, "#FF69B4"), _pixel(10, 3, "#FFD700"),
                _pixel(12, 3, "#FF1493"), _pixel(14, 3, "#FF69B4"),
                _pixel(16, 3, "#FFD700")
            ));
        } else if (accessory == 11) {
            // Monocle on the right eye
            return string(abi.encodePacked(
                _rect(13, 7, 2, 2, "#C0C0C0"),
                _pixel(14, 8, eyeColor)
            ));
        } else if (accessory == 12) {
            // Cape — red fabric peeking out from the sides + collar
            return string(abi.encodePacked(
                _rect(3, 13, 2, 7, "#B22222"),
                _rect(19, 13, 2, 7, "#B22222"),
                _rect(7, 12, 10, 1, "#B22222")
            ));
        } else if (accessory == 13) {
            // Halo — thin golden ring floating above the head
            return string(abi.encodePacked(
                _rect(9, 1, 6, 1, "#FFD700"),
                _pixel(8, 1, "#FFD700"), _pixel(15, 1, "#FFD700")
            ));
        } else if (accessory == 14) {
            // Headphones — black band over the head with ear cups
            return string(abi.encodePacked(
                _rect(7, 3, 10, 1, "#000"),
                _rect(6, 3, 1, 4, "#000"),
                _rect(17, 3, 1, 4, "#000"),
                _pixel(6, 4, "#FF1493"), _pixel(17, 4, "#FF1493")
            ));
        }
        return "";
    }

    function _getBodyColor(uint256 seed) private pure returns (string memory) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 colorIndex = uint8(seed % 30);
        if (colorIndex == 0) return "#FF8C42";      // Orange
        if (colorIndex == 1) return "#2C2C2C";      // Black
        if (colorIndex == 2) return "#F5F5F5";      // White
        if (colorIndex == 3) return "#A9A9A9";      // Gray
        if (colorIndex == 4) return "#D4B896";      // Siamese
        if (colorIndex == 5) return "#87CEEB";      // Blue
        if (colorIndex == 6) return "#FFD700";      // Golden
        if (colorIndex == 7) return "#FFB6C1";      // Pink
        if (colorIndex == 8) return "#C0C0C0";      // Chrome
        if (colorIndex == 9) return "#8B4513";      // Brown
        if (colorIndex == 10) return "#FF1493";     // Rainbow base
        if (colorIndex == 11) return "#E6E6FA";     // Lavender
        if (colorIndex == 12) return "#98FF98";     // Mint
        if (colorIndex == 13) return "#FF7F50";     // Coral
        if (colorIndex == 14) return "#008080";     // Teal
        if (colorIndex == 15) return "#FFDAB9";     // Peach
        if (colorIndex == 16) return "#800020";     // Burgundy
        if (colorIndex == 17) return "#000080";     // Navy
        if (colorIndex == 18) return "#50C878";     // Emerald
        if (colorIndex == 19) return "#B76E79";     // Rose Gold
        if (colorIndex == 20) return "#DC143C";     // Crimson
        if (colorIndex == 21) return "#40E0D0";     // Turquoise
        if (colorIndex == 22) return "#8A2BE2";     // Violet
        if (colorIndex == 23) return "#808000";     // Olive
        if (colorIndex == 24) return "#9B30FF";     // Cosmic Purple
        if (colorIndex == 25) return "#39FF14";     // Neon Green
        if (colorIndex == 26) return "#FF6347";     // Sunset Orange
        if (colorIndex == 27) return "#B9F2FF";     // Diamond
        if (colorIndex == 28) return "#4B0082";     // Galaxy
        return "#E0B0FF";                            // Holographic
    }

    function _getEyeColor(uint256 seed) private pure returns (string memory) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 colorIndex = uint8((seed >> 32) % 20);
        if (colorIndex == 0) return "#00FF00";
        if (colorIndex == 1) return "#0000FF";
        if (colorIndex == 2) return "#FFD700";
        if (colorIndex == 3) return "#FF69B4";
        if (colorIndex == 4) return "#8B4513";
        if (colorIndex == 5) return "#00FFFF";
        if (colorIndex == 6) return "#FF0000";
        if (colorIndex == 7) return "#9370DB";
        if (colorIndex == 8) return "#FFBF00";
        if (colorIndex == 9) return "#EE82EE";
        if (colorIndex == 10) return "#40E0D0";
        if (colorIndex == 11) return "#C0C0C0";
        if (colorIndex == 12) return "#00FF00";
        if (colorIndex == 13) return "#4B0082";
        if (colorIndex == 14) return "#FFA500";
        if (colorIndex == 15) return "#0F52BA";
        if (colorIndex == 16) return "#50C878";
        if (colorIndex == 17) return "#FF1493";
        if (colorIndex == 18) return "#FF0033";
        return "#1E90FF";
    }

    function _adjustBrightness(string memory /* color */, int8 /* adjustment */) private pure returns (string memory) {
        // Simplified shade — returns a fixed darker accent that contrasts
        // with most body colors. Used for stripes/spots/patches.
        return "#5C4033";
    }

    function _pixel(uint256 x, uint256 y, string memory color) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<rect x="', (x * 20).toString(), '" y="', (y * 20).toString(),
            '" width="20" height="20" fill="', color, '"/>'
        ));
    }

    function _rect(uint256 x, uint256 y, uint256 w, uint256 h, string memory color) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<rect x="', (x * 20).toString(), '" y="', (y * 20).toString(),
            '" width="', (w * 20).toString(), '" height="', (h * 20).toString(),
            '" fill="', color, '"/>'
        ));
    }
}
