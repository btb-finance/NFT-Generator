// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title PixelCatsRenderer
 * @dev Handles all pixel art generation and SVG rendering
 */
contract PixelCatsRenderer {
    using Strings for uint256;

    /**
     * @dev Build complete pixel cat SVG with 24x24 grid
     */
    function buildPixelCat(uint256 seed) external pure returns (string memory) {
        string memory pixels = _drawCatPixels(seed);
        string memory bgColor = _getBackground(seed);

        return string(abi.encodePacked(
            '<svg width="480" height="480" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">',
            '<rect width="480" height="480" fill="', bgColor, '"/>',
            pixels,
            '</svg>'
        ));
    }

    function _getBackground(uint256 seed) private pure returns (string memory) {
        uint8 bgIndex = uint8((seed >> 40) % 7);

        if (bgIndex == 0) return "#87CEEB";  // Sky Blue
        if (bgIndex == 1) return "#FFB6C1";  // Pink Dream
        if (bgIndex == 2) return "#228B22";  // Forest Green
        if (bgIndex == 3) return "#191970";  // Night Sky
        if (bgIndex == 4) return "#9B59B6";  // Purple Nebula
        if (bgIndex == 5) return "#FFA500";  // Sunset Orange
        return "#FF69B4";  // Hot Pink
    }

    function _drawCatPixels(uint256 seed) private pure returns (string memory) {
        string memory bodyColor = _getBodyColor(seed);
        string memory darkerShade = _adjustBrightness(bodyColor, -30);
        uint8 expression = uint8((seed >> 8) % 10);
        uint8 pattern = uint8((seed >> 16) % 8);
        uint8 accessory = uint8((seed >> 24) % 12);
        string memory eyeColor = _getEyeColor(seed);

        string memory output = "";

        // Ears outline
        output = string(abi.encodePacked(output, _pixel(7, 2, "#000"), _pixel(8, 2, "#000")));
        output = string(abi.encodePacked(output, _pixel(15, 2, "#000"), _pixel(16, 2, "#000")));

        // Ears filled
        output = string(abi.encodePacked(output, _rect(7, 3, 2, 2, bodyColor)));
        output = string(abi.encodePacked(output, _rect(15, 3, 2, 2, bodyColor)));

        // Head outline
        output = string(abi.encodePacked(output, _rect(6, 5, 1, 6, "#000")));
        output = string(abi.encodePacked(output, _rect(17, 5, 1, 6, "#000")));
        output = string(abi.encodePacked(output, _rect(7, 4, 10, 1, "#000")));
        output = string(abi.encodePacked(output, _rect(7, 11, 10, 1, "#000")));

        // Head filled
        output = string(abi.encodePacked(output, _rect(7, 5, 10, 6, bodyColor)));

        // Eyes based on expression
        if (expression == 0) { // Happy
            output = string(abi.encodePacked(output, _rect(8, 7, 3, 3, eyeColor)));
            output = string(abi.encodePacked(output, _rect(13, 7, 3, 3, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(9, 8, "#000"), _pixel(14, 8, "#000")));
        } else if (expression == 1) { // Sleepy
            output = string(abi.encodePacked(output, _rect(8, 8, 3, 1, "#000")));
            output = string(abi.encodePacked(output, _rect(13, 8, 3, 1, "#000")));
        } else if (expression == 2) { // Winking
            output = string(abi.encodePacked(output, _rect(8, 7, 3, 3, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(9, 8, "#000")));
            output = string(abi.encodePacked(output, _rect(13, 8, 3, 1, "#000")));
        } else if (expression == 3) { // Surprised
            output = string(abi.encodePacked(output, _rect(8, 7, 3, 3, eyeColor)));
            output = string(abi.encodePacked(output, _rect(13, 7, 3, 3, eyeColor)));
            output = string(abi.encodePacked(output, _rect(9, 8, 1, 1, "#FFF")));
            output = string(abi.encodePacked(output, _rect(14, 8, 1, 1, "#FFF")));
        } else if (expression == 4) { // Grumpy
            output = string(abi.encodePacked(output, _rect(8, 8, 3, 2, eyeColor)));
            output = string(abi.encodePacked(output, _rect(13, 8, 3, 2, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(8, 7, "#000"), _pixel(10, 7, "#000")));
            output = string(abi.encodePacked(output, _pixel(13, 7, "#000"), _pixel(15, 7, "#000")));
        } else if (expression == 5) { // Loving (hearts)
            output = string(abi.encodePacked(output, _pixel(8, 8, "#FF1493"), _pixel(10, 8, "#FF1493")));
            output = string(abi.encodePacked(output, _pixel(13, 8, "#FF1493"), _pixel(15, 8, "#FF1493")));
            output = string(abi.encodePacked(output, _rect(8, 9, 3, 1, "#FF1493")));
            output = string(abi.encodePacked(output, _rect(13, 9, 3, 1, "#FF1493")));
        } else if (expression == 6) { // Excited (wide eyes, open mouth)
            output = string(abi.encodePacked(output, _rect(8, 6, 3, 4, "#FFF")));
            output = string(abi.encodePacked(output, _rect(13, 6, 3, 4, "#FFF")));
            output = string(abi.encodePacked(output, _rect(9, 7, 1, 2, eyeColor)));
            output = string(abi.encodePacked(output, _rect(14, 7, 1, 2, eyeColor)));
            output = string(abi.encodePacked(output, _rect(10, 11, 4, 1, "#000")));
        } else if (expression == 7) { // Shy (half-closed eyes)
            output = string(abi.encodePacked(output, _rect(8, 8, 3, 2, eyeColor)));
            output = string(abi.encodePacked(output, _rect(13, 8, 3, 2, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(9, 9, "#000"), _pixel(14, 9, "#000")));
        } else if (expression == 8) { // Curious (one eyebrow raised)
            output = string(abi.encodePacked(output, _rect(8, 7, 3, 3, eyeColor)));
            output = string(abi.encodePacked(output, _rect(13, 7, 3, 3, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(9, 8, "#000"), _pixel(14, 8, "#000")));
            output = string(abi.encodePacked(output, _pixel(7, 6, "#000"), _pixel(8, 6, "#000")));
        } else { // Normal (9)
            output = string(abi.encodePacked(output, _rect(8, 7, 3, 3, eyeColor)));
            output = string(abi.encodePacked(output, _rect(13, 7, 3, 3, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(9, 8, "#000"), _pixel(14, 8, "#000")));
        }

        // Nose
        output = string(abi.encodePacked(output, _rect(11, 9, 2, 1, "#FFC0CB")));

        // Whiskers
        output = string(abi.encodePacked(output, _rect(4, 8, 2, 1, "#000")));
        output = string(abi.encodePacked(output, _rect(18, 8, 2, 1, "#000")));

        // Body outline
        output = string(abi.encodePacked(output, _rect(6, 12, 1, 7, "#000")));
        output = string(abi.encodePacked(output, _rect(17, 12, 1, 7, "#000")));
        output = string(abi.encodePacked(output, _rect(7, 19, 10, 1, "#000")));

        // Body filled
        output = string(abi.encodePacked(output, _rect(7, 12, 10, 7, bodyColor)));

        // Belly
        output = string(abi.encodePacked(output, _rect(9, 13, 6, 5, darkerShade)));

        // Front paws
        output = string(abi.encodePacked(output, _rect(7, 17, 3, 2, bodyColor)));
        output = string(abi.encodePacked(output, _rect(14, 17, 3, 2, bodyColor)));

        // Tail
        output = string(abi.encodePacked(output, _rect(17, 14, 2, 4, bodyColor)));
        output = string(abi.encodePacked(output, _pixel(18, 14, "#000")));

        // Apply pattern
        if (pattern == 1) { // Striped
            output = string(abi.encodePacked(output, _rect(8, 5, 1, 6, darkerShade)));
            output = string(abi.encodePacked(output, _rect(10, 5, 1, 6, darkerShade)));
            output = string(abi.encodePacked(output, _rect(12, 5, 1, 6, darkerShade)));
        } else if (pattern == 2) { // Spotted
            output = string(abi.encodePacked(output, _pixel(8, 6, darkerShade), _pixel(15, 7, darkerShade)));
            output = string(abi.encodePacked(output, _pixel(10, 14, darkerShade), _pixel(14, 15, darkerShade)));
        } else if (pattern == 3) { // Tuxedo
            output = string(abi.encodePacked(output, _rect(11, 13, 2, 5, "#FFF")));
        } else if (pattern == 4) { // Patches
            output = string(abi.encodePacked(output, _rect(7, 6, 3, 3, darkerShade)));
            output = string(abi.encodePacked(output, _rect(14, 8, 3, 3, darkerShade)));
        } else if (pattern == 5) { // Tiger Stripes
            output = string(abi.encodePacked(output, _rect(7, 6, 2, 1, "#000")));
            output = string(abi.encodePacked(output, _rect(8, 13, 2, 1, "#000")));
        } else if (pattern == 6) { // Gradient (simplified - darker bottom)
            output = string(abi.encodePacked(output, _rect(7, 14, 10, 2, darkerShade)));
            output = string(abi.encodePacked(output, _rect(7, 16, 10, 1, darkerShade)));
        } else if (pattern == 7) { // Calico (multi-color patches)
            output = string(abi.encodePacked(output, _rect(7, 6, 3, 3, "#FF8C42")));
            output = string(abi.encodePacked(output, _rect(14, 8, 3, 3, "#2C2C2C")));
            output = string(abi.encodePacked(output, _rect(10, 14, 3, 2, "#FFF")));
        }

        // Apply accessory
        if (accessory == 1) { // Crown
            output = string(abi.encodePacked(output, _rect(9, 2, 6, 2, "#FFD700")));
            output = string(abi.encodePacked(output, _pixel(10, 1, "#FFD700"), _pixel(12, 1, "#FFD700"), _pixel(14, 1, "#FFD700")));
        } else if (accessory == 2) { // Top Hat
            output = string(abi.encodePacked(output, _rect(9, 0, 6, 2, "#000")));
            output = string(abi.encodePacked(output, _rect(8, 2, 8, 1, "#000")));
        } else if (accessory == 3) { // Bow Tie
            output = string(abi.encodePacked(output, _rect(10, 12, 1, 2, "#FF0000")));
            output = string(abi.encodePacked(output, _rect(13, 12, 1, 2, "#FF0000")));
            output = string(abi.encodePacked(output, _pixel(11, 13, "#FF0000"), _pixel(12, 13, "#FF0000")));
        } else if (accessory == 4) { // Sunglasses
            output = string(abi.encodePacked(output, _rect(7, 7, 4, 3, "#000")));
            output = string(abi.encodePacked(output, _rect(13, 7, 4, 3, "#000")));
            output = string(abi.encodePacked(output, _rect(11, 8, 2, 1, "#000")));
        } else if (accessory == 5) { // Bandana
            output = string(abi.encodePacked(output, _rect(7, 4, 10, 1, "#FF0000")));
            output = string(abi.encodePacked(output, _pixel(6, 5, "#FF0000"), _pixel(17, 5, "#FF0000")));
        } else if (accessory == 6) { // Astronaut Helmet
            output = string(abi.encodePacked(output, _rect(6, 4, 12, 8, "rgba(173,216,230,0.5)")));
        } else if (accessory == 7) { // Pirate Eye Patch
            output = string(abi.encodePacked(output, _rect(13, 7, 3, 3, "#000")));
            output = string(abi.encodePacked(output, _rect(7, 6, 10, 1, "#000")));
        } else if (accessory == 8) { // Golden Crown (fancier)
            output = string(abi.encodePacked(output, _rect(8, 1, 8, 3, "#FFD700")));
            output = string(abi.encodePacked(output, _pixel(9, 0, "#FFD700"), _pixel(11, 0, "#FFD700"), _pixel(13, 0, "#FFD700"), _pixel(15, 0, "#FFD700")));
        } else if (accessory == 9) { // Wizard Hat
            output = string(abi.encodePacked(output, _rect(11, 0, 2, 3, "#4B0082")));
            output = string(abi.encodePacked(output, _rect(10, 3, 4, 1, "#4B0082")));
            output = string(abi.encodePacked(output, _pixel(12, 2, "#FFD700")));
        } else if (accessory == 10) { // Flower Crown
            output = string(abi.encodePacked(output, _pixel(8, 3, "#FF69B4"), _pixel(10, 3, "#FFD700")));
            output = string(abi.encodePacked(output, _pixel(12, 3, "#FF1493"), _pixel(14, 3, "#FF69B4")));
            output = string(abi.encodePacked(output, _pixel(16, 3, "#FFD700")));
        } else if (accessory == 11) { // Monocle
            output = string(abi.encodePacked(output, _rect(13, 8, 2, 2, "#C0C0C0")));
            output = string(abi.encodePacked(output, _pixel(14, 9, eyeColor)));
            output = string(abi.encodePacked(output, _rect(15, 8, 1, 1, "#C0C0C0")));
        }

        return output;
    }

    function _getBodyColor(uint256 seed) private pure returns (string memory) {
        // Casting to uint8 is safe because we mod by 20, max value is 19
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 colorIndex = uint8(seed % 20);

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
        if (colorIndex == 10) return "#FF1493";     // Rainbow (magenta base)
        if (colorIndex == 11) return "#E6E6FA";     // Lavender
        if (colorIndex == 12) return "#98FF98";     // Mint
        if (colorIndex == 13) return "#FF7F50";     // Coral
        if (colorIndex == 14) return "#008080";     // Teal
        if (colorIndex == 15) return "#FFDAB9";     // Peach
        if (colorIndex == 16) return "#800020";     // Burgundy
        if (colorIndex == 17) return "#000080";     // Navy
        if (colorIndex == 18) return "#50C878";     // Emerald
        return "#B76E79";                            // Rose Gold
    }

    function _getEyeColor(uint256 seed) private pure returns (string memory) {
        uint8 colorIndex = uint8((seed >> 32) % 15);

        if (colorIndex == 0) return "#00FF00";      // Green
        if (colorIndex == 1) return "#0000FF";      // Blue
        if (colorIndex == 2) return "#FFD700";      // Gold
        if (colorIndex == 3) return "#FF69B4";      // Pink
        if (colorIndex == 4) return "#8B4513";      // Brown
        if (colorIndex == 5) return "#00FFFF";      // Cyan
        if (colorIndex == 6) return "#FF0000";      // Red
        if (colorIndex == 7) return "#9370DB";      // Purple
        if (colorIndex == 8) return "#FFBF00";      // Amber
        if (colorIndex == 9) return "#EE82EE";      // Violet
        if (colorIndex == 10) return "#40E0D0";     // Turquoise
        if (colorIndex == 11) return "#C0C0C0";     // Silver
        if (colorIndex == 12) return "#00FF00";     // Lime
        if (colorIndex == 13) return "#4B0082";     // Indigo
        return "#FFA500";                            // Orange
    }

    function _adjustBrightness(string memory /* color */, int8 /* adjustment */) private pure returns (string memory) {
        // Simplified: just return a darker preset shade
        return "#8B7355";  // Generic darker brown shade
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
