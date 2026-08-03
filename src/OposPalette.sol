// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/**
 * @title OposPalette
 * @dev Colour lookups for the OPOSSUM collection, split into their own
 *      deployed contract to keep each piece of the renderer inside the
 *      EIP-170 24,576-byte limit.
 *
 *      Indices are derived from the same seed bit ranges OposNFT uses for the
 *      textual traits, so the art and the metadata can never disagree:
 *        body       = seed % 30
 *        eye        = (seed >> 32) % 20
 *        background = (seed >> 40) % 7
 */
contract OposPalette {
    function backgroundColor(uint256 seed) external pure returns (string memory) {
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

    function bodyColor(uint256 seed) external pure returns (string memory) {
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

    function eyeColor(uint256 seed) external pure returns (string memory) {
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
}
