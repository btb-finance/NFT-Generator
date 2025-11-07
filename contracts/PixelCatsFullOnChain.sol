// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title PixelCatsFullOnChain
 * @dev Fully on-chain pixel art generation - COMPLETE SVG RENDERING
 * WARNING: This is gas-intensive but 100% on-chain forever
 */
contract PixelCatsFullOnChain is ERC721, Ownable {
    using Strings for uint256;

    uint256 private _tokenIdCounter;
    mapping(uint256 => uint256) private tokenTraits;

    constructor() ERC721("Pixel Cats Full On Chain", "PXCATFULL") Ownable(msg.sender) {}

    function mint() external payable {
        uint256 tokenId = _tokenIdCounter++;
        uint256 traits = _generateTraits(tokenId);
        tokenTraits[tokenId] = traits;
        _safeMint(msg.sender, tokenId);
    }

    /**
     * @dev Bulk mint multiple cats at once (FREE for testing!)
     * @param amount Number of cats to mint (max 200 per transaction)
     */
    function bulkMint(uint256 amount) external payable {
        require(amount > 0 && amount <= 200, "Amount must be 1-200");

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter++;
            uint256 traits = _generateTraits(tokenId);
            tokenTraits[tokenId] = traits;
            _safeMint(msg.sender, tokenId);
        }
    }

    function _generateTraits(uint256 tokenId) private view returns (uint256) {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, tokenId, msg.sender)));
        return seed;
    }

    /**
     * @dev Generate complete pixel art SVG on-chain
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");

        string memory svg = _buildPixelCat(tokenTraits[tokenId]);
        string memory json = string(abi.encodePacked(
            '{"name":"Pixel Cat #', tokenId.toString(), '",',
            '"description":"100% on-chain pixel art cat",',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        ));

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /**
     * @dev Build complete pixel cat SVG with 24x24 grid
     */
    function _buildPixelCat(uint256 seed) private pure returns (string memory) {
        string memory pixels = _drawCatPixels(seed);

        return string(abi.encodePacked(
            '<svg width="480" height="480" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">',
            '<rect width="480" height="480" fill="#87CEEB"/>',
            pixels,
            '</svg>'
        ));
    }

    /**
     * @dev Draw cat as individual pixels (20px each on 24x24 grid)
     * This creates the actual pixel art cat matching TypeScript implementation
     */
    function _drawCatPixels(uint256 seed) private pure returns (string memory) {
        string memory bodyColor = _getBodyColor(seed);
        string memory darkerShade = _adjustBrightness(bodyColor, -30);
        uint8 expression = uint8((seed >> 8) % 7);
        uint8 pattern = uint8((seed >> 16) % 6);
        uint8 accessory = uint8((seed >> 24) % 9);
        string memory eyeColor = _getEyeColor(seed);
        string memory output = "";

        // Draw cat head outline - top
        output = string(abi.encodePacked(output, _rect(9, 3, 6, 1, "#000")));

        // Upper head with rounded corners
        output = string(abi.encodePacked(output, _rect(8, 4, 8, 1, bodyColor)));
        output = string(abi.encodePacked(output, _pixel(7, 4, "#000"), _pixel(16, 4, "#000")));

        // Main head area
        output = string(abi.encodePacked(output, _rect(6, 5, 12, 7, bodyColor)));
        output = string(abi.encodePacked(output, _pixel(6, 5, "#000"), _pixel(17, 5, "#000")));
        output = string(abi.encodePacked(output, _pixel(5, 6, "#000"), _pixel(18, 6, "#000")));

        // Head outline sides
        for (uint y = 7; y <= 10; y++) {
            output = string(abi.encodePacked(output, _pixel(5, y, "#000"), _pixel(18, y, "#000")));
        }

        // Bottom of head - chin
        output = string(abi.encodePacked(output, _pixel(6, 11, "#000"), _pixel(17, 11, "#000")));
        output = string(abi.encodePacked(output, _rect(7, 12, 10, 1, "#000")));

        // Left ear
        output = string(abi.encodePacked(output, _pixel(7, 2, "#000")));
        output = string(abi.encodePacked(output, _rect(7, 3, 2, 1, bodyColor)));
        output = string(abi.encodePacked(output, _pixel(6, 3, "#000"), _pixel(9, 3, "#000")));
        output = string(abi.encodePacked(output, _rect(6, 4, 2, 1, bodyColor)));
        output = string(abi.encodePacked(output, _pixel(8, 4, darkerShade)));

        // Right ear
        output = string(abi.encodePacked(output, _pixel(16, 2, "#000")));
        output = string(abi.encodePacked(output, _rect(15, 3, 2, 1, bodyColor)));
        output = string(abi.encodePacked(output, _pixel(14, 3, "#000"), _pixel(17, 3, "#000")));
        output = string(abi.encodePacked(output, _rect(16, 4, 2, 1, bodyColor)));
        output = string(abi.encodePacked(output, _pixel(15, 4, darkerShade)));

        // Cat body - sitting pose
        output = string(abi.encodePacked(output, _rect(8, 13, 8, 1, "#000")));
        output = string(abi.encodePacked(output, _rect(7, 14, 10, 5, bodyColor)));
        for (uint y = 14; y <= 17; y++) {
            output = string(abi.encodePacked(output, _pixel(6, y, "#000"), _pixel(17, y, "#000")));
        }
        output = string(abi.encodePacked(output, _rect(6, 18, 12, 1, "#000")));

        // Front paws
        output = string(abi.encodePacked(output, _rect(8, 19, 2, 2, bodyColor)));
        output = string(abi.encodePacked(output, _rect(14, 19, 2, 2, bodyColor)));
        output = string(abi.encodePacked(output, _pixel(7, 19, "#000"), _pixel(7, 20, "#000")));
        output = string(abi.encodePacked(output, _pixel(8, 21, "#000"), _pixel(9, 21, "#000")));
        output = string(abi.encodePacked(output, _pixel(16, 19, "#000"), _pixel(16, 20, "#000")));
        output = string(abi.encodePacked(output, _pixel(14, 21, "#000"), _pixel(15, 21, "#000")));

        // Tail
        output = string(abi.encodePacked(output, _pixel(18, 16, "#000")));
        output = string(abi.encodePacked(output, _rect(19, 15, 1, 2, bodyColor)));
        output = string(abi.encodePacked(output, _pixel(18, 15, "#000"), _pixel(20, 15, "#000")));
        output = string(abi.encodePacked(output, _pixel(20, 16, "#000"), _pixel(19, 17, "#000")));

        // Add pattern
        output = string(abi.encodePacked(output, _drawPattern(pattern, bodyColor, darkerShade)));

        // Draw face (eyes, nose, mouth)
        output = string(abi.encodePacked(output, _drawFace(expression, eyeColor)));

        // Draw whiskers
        for (uint y = 8; y <= 10; y++) {
            output = string(abi.encodePacked(output, _pixel(3, y, "#000"), _pixel(4, y, "#000")));
            output = string(abi.encodePacked(output, _pixel(19, y, "#000"), _pixel(20, y, "#000")));
        }

        // Cheek marks
        output = string(abi.encodePacked(output, _pixel(7, 9, "#FFB6C1"), _pixel(7, 10, "#FFB6C1")));
        output = string(abi.encodePacked(output, _pixel(16, 9, "#FFB6C1"), _pixel(16, 10, "#FFB6C1")));

        // Draw accessory
        output = string(abi.encodePacked(output, _drawAccessory(accessory)));

        return output;
    }

    function _drawPattern(uint8 pattern, string memory bodyColor, string memory darkerShade) private pure returns (string memory) {
        string memory output = "";

        if (pattern == 1) { // Striped
            output = string(abi.encodePacked(output, _rect(9, 14, 1, 4, darkerShade)));
            output = string(abi.encodePacked(output, _rect(12, 14, 1, 4, darkerShade)));
            output = string(abi.encodePacked(output, _rect(10, 6, 1, 2, darkerShade)));
            output = string(abi.encodePacked(output, _rect(13, 6, 1, 2, darkerShade)));
        } else if (pattern == 2) { // Spotted
            output = string(abi.encodePacked(output, _rect(9, 15, 2, 2, darkerShade)));
            output = string(abi.encodePacked(output, _rect(14, 16, 2, 2, darkerShade)));
            output = string(abi.encodePacked(output, _pixel(10, 7, darkerShade)));
            output = string(abi.encodePacked(output, _pixel(13, 8, darkerShade)));
        } else if (pattern == 3) { // Tuxedo
            output = string(abi.encodePacked(output, _rect(10, 14, 4, 4, "#FFF")));
            output = string(abi.encodePacked(output, _rect(8, 19, 2, 2, "#FFF")));
            output = string(abi.encodePacked(output, _rect(14, 19, 2, 2, "#FFF")));
        } else if (pattern == 4) { // Patches
            string memory patchColor = _adjustBrightness(bodyColor, 40);
            output = string(abi.encodePacked(output, _rect(7, 6, 2, 2, patchColor)));
            output = string(abi.encodePacked(output, _rect(15, 8, 2, 2, patchColor)));
            output = string(abi.encodePacked(output, _rect(11, 15, 2, 2, patchColor)));
        } else if (pattern == 5) { // Tiger Stripes
            output = string(abi.encodePacked(output, _rect(8, 6, 1, 3, darkerShade)));
            output = string(abi.encodePacked(output, _rect(11, 7, 1, 2, darkerShade)));
            output = string(abi.encodePacked(output, _rect(14, 6, 1, 3, darkerShade)));
            output = string(abi.encodePacked(output, _rect(8, 14, 1, 4, darkerShade)));
            output = string(abi.encodePacked(output, _rect(12, 15, 1, 3, darkerShade)));
            output = string(abi.encodePacked(output, _rect(15, 14, 1, 4, darkerShade)));
        }

        return output;
    }

    function _drawFace(uint8 expression, string memory eyeColor) private pure returns (string memory) {
        string memory output = "";

        if (expression == 0) { // Happy
            // Left eye
            output = string(abi.encodePacked(output, _rect(8, 7, 3, 2, "#FFF")));
            output = string(abi.encodePacked(output, _pixel(8, 7, "#000"), _pixel(10, 7, "#000")));
            output = string(abi.encodePacked(output, _pixel(9, 8, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(8, 9, "#000"), _pixel(9, 9, "#000"), _pixel(10, 9, "#000")));
            // Right eye
            output = string(abi.encodePacked(output, _rect(13, 7, 3, 2, "#FFF")));
            output = string(abi.encodePacked(output, _pixel(13, 7, "#000"), _pixel(15, 7, "#000")));
            output = string(abi.encodePacked(output, _pixel(14, 8, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(13, 9, "#000"), _pixel(14, 9, "#000"), _pixel(15, 9, "#000")));
            // Smile
            output = string(abi.encodePacked(output, _pixel(10, 11, "#000"), _pixel(13, 11, "#000")));
            output = string(abi.encodePacked(output, _pixel(9, 10, "#000"), _pixel(14, 10, "#000")));
        } else if (expression == 1) { // Sleepy
            output = string(abi.encodePacked(output, _rect(8, 8, 3, 1, "#000")));
            output = string(abi.encodePacked(output, _rect(13, 8, 3, 1, "#000")));
            output = string(abi.encodePacked(output, _pixel(7, 7, "#000"), _pixel(11, 7, "#000")));
            output = string(abi.encodePacked(output, _pixel(12, 7, "#000"), _pixel(16, 7, "#000")));
        } else if (expression == 2) { // Winking
            output = string(abi.encodePacked(output, _rect(8, 8, 3, 1, "#000")));
            output = string(abi.encodePacked(output, _pixel(7, 7, "#000"), _pixel(11, 7, "#000")));
            output = string(abi.encodePacked(output, _rect(13, 7, 3, 3, "#FFF")));
            output = string(abi.encodePacked(output, _pixel(13, 7, "#000"), _pixel(14, 7, "#000"), _pixel(15, 7, "#000")));
            output = string(abi.encodePacked(output, _rect(14, 8, 1, 2, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(14, 9, "#000")));
        } else if (expression == 3) { // Surprised
            output = string(abi.encodePacked(output, _rect(8, 6, 3, 4, "#FFF")));
            output = string(abi.encodePacked(output, _rect(8, 6, 3, 1, "#000")));
            output = string(abi.encodePacked(output, _pixel(7, 7, "#000"), _pixel(11, 7, "#000")));
            output = string(abi.encodePacked(output, _pixel(7, 8, "#000"), _pixel(11, 8, "#000")));
            output = string(abi.encodePacked(output, _rect(9, 8, 1, 2, eyeColor)));
            output = string(abi.encodePacked(output, _rect(13, 6, 3, 4, "#FFF")));
            output = string(abi.encodePacked(output, _rect(13, 6, 3, 1, "#000")));
            output = string(abi.encodePacked(output, _pixel(12, 7, "#000"), _pixel(16, 7, "#000")));
            output = string(abi.encodePacked(output, _pixel(12, 8, "#000"), _pixel(16, 8, "#000")));
            output = string(abi.encodePacked(output, _rect(14, 8, 1, 2, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(11, 11, "#000"), _pixel(12, 11, "#000")));
        } else if (expression == 4) { // Grumpy
            output = string(abi.encodePacked(output, _rect(8, 8, 3, 2, "#FFF")));
            output = string(abi.encodePacked(output, _pixel(7, 7, "#000"), _pixel(8, 7, "#000")));
            output = string(abi.encodePacked(output, _pixel(10, 9, "#000"), _pixel(11, 9, "#000")));
            output = string(abi.encodePacked(output, _pixel(9, 8, eyeColor)));
            output = string(abi.encodePacked(output, _rect(13, 8, 3, 2, "#FFF")));
            output = string(abi.encodePacked(output, _pixel(15, 7, "#000"), _pixel(16, 7, "#000")));
            output = string(abi.encodePacked(output, _pixel(12, 9, "#000"), _pixel(13, 9, "#000")));
            output = string(abi.encodePacked(output, _pixel(14, 8, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(10, 10, "#000"), _pixel(13, 10, "#000")));
        } else if (expression == 5) { // Loving (hearts)
            output = string(abi.encodePacked(output, _pixel(8, 7, "#FF69B4"), _pixel(10, 7, "#FF69B4")));
            output = string(abi.encodePacked(output, _rect(7, 8, 5, 1, "#FF69B4")));
            output = string(abi.encodePacked(output, _rect(8, 9, 3, 1, "#FF69B4")));
            output = string(abi.encodePacked(output, _pixel(9, 10, "#FF69B4")));
            output = string(abi.encodePacked(output, _pixel(13, 7, "#FF69B4"), _pixel(15, 7, "#FF69B4")));
            output = string(abi.encodePacked(output, _rect(12, 8, 5, 1, "#FF69B4")));
            output = string(abi.encodePacked(output, _rect(13, 9, 3, 1, "#FF69B4")));
            output = string(abi.encodePacked(output, _pixel(14, 10, "#FF69B4")));
        } else { // Normal
            output = string(abi.encodePacked(output, _rect(8, 7, 3, 3, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(8, 7, "#000"), _pixel(9, 7, "#000"), _pixel(10, 7, "#000")));
            output = string(abi.encodePacked(output, _rect(9, 8, 1, 2, "#000")));
            output = string(abi.encodePacked(output, _pixel(8, 10, "#000"), _pixel(9, 10, "#000"), _pixel(10, 10, "#000")));
            output = string(abi.encodePacked(output, _rect(13, 7, 3, 3, eyeColor)));
            output = string(abi.encodePacked(output, _pixel(13, 7, "#000"), _pixel(14, 7, "#000"), _pixel(15, 7, "#000")));
            output = string(abi.encodePacked(output, _rect(14, 8, 1, 2, "#000")));
            output = string(abi.encodePacked(output, _pixel(13, 10, "#000"), _pixel(14, 10, "#000"), _pixel(15, 10, "#000")));
            output = string(abi.encodePacked(output, _pixel(10, 11, "#000"), _pixel(13, 11, "#000")));
        }

        // Nose (always)
        output = string(abi.encodePacked(output, _pixel(11, 9, "#FF69B4")));
        output = string(abi.encodePacked(output, _rect(11, 10, 2, 1, "#FF69B4")));
        output = string(abi.encodePacked(output, _pixel(11, 11, "#000"), _pixel(12, 11, "#000")));

        return output;
    }

    function _drawAccessory(uint8 accessory) private pure returns (string memory) {
        string memory output = "";

        if (accessory == 1) { // Crown
            output = string(abi.encodePacked(output, _rect(9, 2, 6, 2, "#FFD700")));
            output = string(abi.encodePacked(output, _pixel(9, 1, "#FFD700"), _pixel(11, 1, "#FFD700"), _pixel(13, 1, "#FFD700")));
        } else if (accessory == 2) { // Top Hat
            output = string(abi.encodePacked(output, _rect(10, 0, 4, 2, "#2C2C2C")));
            output = string(abi.encodePacked(output, _rect(8, 2, 8, 1, "#2C2C2C")));
            output = string(abi.encodePacked(output, _rect(10, 1, 4, 1, "#FF0000")));
        } else if (accessory == 3) { // Bow Tie
            output = string(abi.encodePacked(output, _pixel(11, 13, "#FF0000"), _pixel(12, 13, "#FF0000")));
            output = string(abi.encodePacked(output, _pixel(10, 13, "#FF0000"), _pixel(13, 13, "#FF0000")));
            output = string(abi.encodePacked(output, _pixel(11, 12, "#FF0000"), _pixel(12, 12, "#FF0000")));
        } else if (accessory == 4) { // Sunglasses
            output = string(abi.encodePacked(output, _rect(8, 8, 3, 2, "#2C2C2C")));
            output = string(abi.encodePacked(output, _rect(13, 8, 3, 2, "#2C2C2C")));
            output = string(abi.encodePacked(output, _rect(11, 9, 2, 1, "#2C2C2C")));
        } else if (accessory == 5) { // Bandana
            output = string(abi.encodePacked(output, _rect(8, 4, 8, 2, "#FF0000")));
            output = string(abi.encodePacked(output, _pixel(7, 5, "#FF0000"), _pixel(16, 5, "#FF0000")));
        } else if (accessory == 6) { // Astronaut Helmet (simplified)
            output = string(abi.encodePacked(output, _pixel(7, 4, "#C0C0C0"), _pixel(16, 4, "#C0C0C0")));
            output = string(abi.encodePacked(output, _pixel(7, 13, "#C0C0C0"), _pixel(16, 13, "#C0C0C0")));
        } else if (accessory == 7) { // Pirate Eye Patch
            output = string(abi.encodePacked(output, _rect(9, 8, 2, 2, "#2C2C2C")));
            output = string(abi.encodePacked(output, _pixel(8, 7, "#2C2C2C"), _pixel(14, 7, "#2C2C2C")));
        } else if (accessory == 8) { // Golden Crown
            output = string(abi.encodePacked(output, _rect(9, 1, 6, 3, "#FFD700")));
            output = string(abi.encodePacked(output, _pixel(9, 0, "#FFD700"), _pixel(11, 0, "#FFD700"), _pixel(13, 0, "#FFD700")));
            output = string(abi.encodePacked(output, _pixel(10, 2, "#FF0000"), _pixel(12, 2, "#FF0000"), _pixel(14, 2, "#FF0000")));
        }

        return output;
    }

    function _rect(uint x, uint y, uint w, uint h, string memory color) private pure returns (string memory) {
        string memory output = "";
        for (uint i = 0; i < h; i++) {
            for (uint j = 0; j < w; j++) {
                output = string(abi.encodePacked(output, _pixel(x + j, y + i, color)));
            }
        }
        return output;
    }

    function _adjustBrightness(string memory color, int amount) private pure returns (string memory) {
        // Simple brightness adjustment - just return darker/lighter preset colors
        if (amount < 0) {
            return "#1a1a1a"; // Darker shade
        }
        return "#e0e0e0"; // Lighter shade
    }

    function _getEyeColor(uint256 seed) private pure returns (string memory) {
        uint8 colorIndex = uint8((seed >> 32) % 8);

        if (colorIndex == 0) return "#00FF00";  // Green
        if (colorIndex == 1) return "#0000FF";  // Blue
        if (colorIndex == 2) return "#FFD700";  // Gold
        if (colorIndex == 3) return "#FF1493";  // Pink
        if (colorIndex == 4) return "#8B4513";  // Brown
        if (colorIndex == 5) return "#00FFFF";  // Cyan
        if (colorIndex == 6) return "#FF0000";  // Red
        return "#800080";  // Purple
    }

    /**
     * @dev Create a single pixel rect
     */
    function _pixel(uint x, uint y, string memory color) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<rect x="', (x * 20).toString(), '" y="', (y * 20).toString(),
            '" width="20" height="20" fill="', color, '"/>'
        ));
    }

    /**
     * @dev Get body color from seed
     */
    function _getBodyColor(uint256 seed) private pure returns (string memory) {
        uint8 colorIndex = uint8(seed % 11);

        if (colorIndex == 0) return "#FF8C42";  // Orange
        if (colorIndex == 1) return "#2C2C2C";  // Black
        if (colorIndex == 2) return "#F5F5F5";  // White
        if (colorIndex == 3) return "#808080";  // Gray
        if (colorIndex == 4) return "#D4A574";  // Siamese
        if (colorIndex == 5) return "#6495ED";  // Blue
        if (colorIndex == 6) return "#FFD700";  // Golden
        if (colorIndex == 7) return "#FF69B4";  // Pink
        if (colorIndex == 8) return "#C0C0C0";  // Chrome
        if (colorIndex == 9) return "#8B4513";  // Brown
        return "#FF00FF";  // Rainbow
    }

    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
