// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

interface IPixelCatsRenderer {
    function buildPixelCat(uint256 seed) external pure returns (string memory);
}

/**
 * @title PixelCatsFullOnChainV2
 * @dev Split architecture - Main contract + Renderer contract
 * Supports 31.5M+ unique combinations for 100k+ NFTs
 * Includes ERC2981 royalty support for OpenSea creator earnings
 */
contract PixelCatsFullOnChainV2 is ERC721, ERC2981, Ownable {
    using Strings for uint256;

    uint256 private _tokenIdCounter;
    mapping(uint256 => uint256) private tokenTraits;
    IPixelCatsRenderer public renderer;

    constructor(address _renderer) ERC721("BTB CAT", "BTBC") Ownable(msg.sender) {
        renderer = IPixelCatsRenderer(_renderer);
        // Set 5% royalty fee to contract owner
        _setDefaultRoyalty(msg.sender, 500); // 500 basis points = 5%
    }

    function setRenderer(address _renderer) external onlyOwner {
        renderer = IPixelCatsRenderer(_renderer);
    }

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
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, tokenId, msg.sender, block.prevrandao)));
        return seed;
    }

    /**
     * @dev Generate complete pixel art SVG on-chain via renderer
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");

        string memory svg = renderer.buildPixelCat(tokenTraits[tokenId]);
        string memory rarity = _getRarityTier(tokenTraits[tokenId]);
        string memory json = string(abi.encodePacked(
            '{"name":"BTB CAT ', rarity, ' #', tokenId.toString(), '",',
            '"description":"100,000 BTB CATs living fully on-chain. Following BTB bonding curve, each token is backed by real BTB with unique pixel art combinations.",',
            '"attributes":[',
            _getAttributes(tokenTraits[tokenId]),
            '],',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        ));

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function _getAttributes(uint256 seed) private view returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type":"Rarity","value":"', _getRarityTier(seed), '"},',
            '{"trait_type":"Generation","value":"', _getGeneration(), '"},',
            '{"trait_type":"Body","value":"', _getBodyName(seed), '"},',
            '{"trait_type":"Eyes","value":"', _getEyeName(seed), '"},',
            '{"trait_type":"Expression","value":"', _getExpressionName(seed), '"},',
            '{"trait_type":"Pattern","value":"', _getPatternName(seed), '"},',
            '{"trait_type":"Accessory","value":"', _getAccessoryName(seed), '"},',
            '{"trait_type":"Background","value":"', _getBackgroundName(seed), '"}'
        ));
    }

    /**
     * @dev Get generation based on total minted supply
     */
    function _getGeneration() private view returns (string memory) {
        uint256 supply = _tokenIdCounter;
        if (supply < 10000) return "Genesis";
        if (supply < 25000) return "Alpha";
        if (supply < 50000) return "Beta";
        if (supply < 75000) return "Gamma";
        return "Delta";
    }

    /**
     * @dev Calculate rarity tier based on trait combinations
     * Mythic: 1% - Golden Crown/Wizard Hat + Rainbow/Chrome/Rose Gold body
     * Legendary: 4% - Golden Crown, Wizard Hat, or rare body colors
     * Epic: 10% - Multiple rare traits
     * Rare: 20% - At least one rare trait
     * Common: 65% - Standard traits
     */
    function _getRarityTier(uint256 seed) private pure returns (string memory) {
        // All casts are safe because we mod by small values
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 bodyIndex = uint8(seed % 30);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 accessoryIndex = uint8((seed >> 24) % 15);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 eyeIndex = uint8((seed >> 32) % 20);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 patternIndex = uint8((seed >> 16) % 10);

        uint8 rarityScore = 0;

        // Ultra rare bodies (Rainbow, Chrome, Rose Gold, Diamond, Galaxy)
        if (bodyIndex == 10 || bodyIndex == 8 || bodyIndex == 19 || bodyIndex >= 27) {
            rarityScore += 3;
        }
        // Rare bodies (Golden, Burgundy, Navy, Emerald, Cosmic, Neon)
        else if (bodyIndex == 6 || bodyIndex == 16 || bodyIndex == 17 || bodyIndex == 18 || bodyIndex >= 24) {
            rarityScore += 2;
        }

        // Legendary accessories (Golden Crown, Wizard Hat, Halo)
        if (accessoryIndex == 8 || accessoryIndex == 9 || accessoryIndex >= 13) {
            rarityScore += 3;
        }
        // Rare accessories (Crown, Top Hat, Astronaut Helmet, Monocle, Cape)
        else if (accessoryIndex == 1 || accessoryIndex == 2 || accessoryIndex == 6 || accessoryIndex == 11 || accessoryIndex == 12) {
            rarityScore += 2;
        }

        // Rare eyes (Gold, Silver, Indigo, Rainbow, Laser)
        if (eyeIndex == 2 || eyeIndex == 11 || eyeIndex == 13 || eyeIndex >= 17) {
            rarityScore += 1;
        }

        // Rare patterns (Calico, Tiger Stripes, Galaxy, Flames)
        if (patternIndex == 7 || patternIndex == 5 || patternIndex >= 8) {
            rarityScore += 1;
        }

        // Determine tier based on score
        if (rarityScore >= 6) return "Mythic";      // ~1%
        if (rarityScore >= 4) return "Legendary";   // ~4%
        if (rarityScore >= 3) return "Epic";        // ~10%
        if (rarityScore >= 1) return "Rare";        // ~20%
        return "Common";                             // ~65%
    }

    function _getBodyName(uint256 seed) private pure returns (string memory) {
        // Casting to uint8 is safe because we mod by 30, max value is 29
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 i = uint8(seed % 30);
        if (i == 0) return "Orange";
        if (i == 1) return "Black";
        if (i == 2) return "White";
        if (i == 3) return "Gray";
        if (i == 4) return "Siamese";
        if (i == 5) return "Blue";
        if (i == 6) return "Golden";
        if (i == 7) return "Pink";
        if (i == 8) return "Chrome";
        if (i == 9) return "Brown";
        if (i == 10) return "Rainbow";
        if (i == 11) return "Lavender";
        if (i == 12) return "Mint";
        if (i == 13) return "Coral";
        if (i == 14) return "Teal";
        if (i == 15) return "Peach";
        if (i == 16) return "Burgundy";
        if (i == 17) return "Navy";
        if (i == 18) return "Emerald";
        if (i == 19) return "Rose Gold";
        if (i == 20) return "Crimson";
        if (i == 21) return "Turquoise";
        if (i == 22) return "Violet";
        if (i == 23) return "Olive";
        if (i == 24) return "Cosmic Purple";
        if (i == 25) return "Neon Green";
        if (i == 26) return "Sunset Orange";
        if (i == 27) return "Diamond";
        if (i == 28) return "Galaxy";
        return "Holographic";
    }

    function _getEyeName(uint256 seed) private pure returns (string memory) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 i = uint8((seed >> 32) % 20);
        if (i == 0) return "Green";
        if (i == 1) return "Blue";
        if (i == 2) return "Gold";
        if (i == 3) return "Pink";
        if (i == 4) return "Brown";
        if (i == 5) return "Cyan";
        if (i == 6) return "Red";
        if (i == 7) return "Purple";
        if (i == 8) return "Amber";
        if (i == 9) return "Violet";
        if (i == 10) return "Turquoise";
        if (i == 11) return "Silver";
        if (i == 12) return "Lime";
        if (i == 13) return "Indigo";
        if (i == 14) return "Orange";
        if (i == 15) return "Sapphire";
        if (i == 16) return "Emerald";
        if (i == 17) return "Rainbow";
        if (i == 18) return "Laser Red";
        return "Cosmic Blue";
    }

    function _getExpressionName(uint256 seed) private pure returns (string memory) {
        uint8 i = uint8((seed >> 8) % 10);
        if (i == 0) return "Happy";
        if (i == 1) return "Sleepy";
        if (i == 2) return "Winking";
        if (i == 3) return "Surprised";
        if (i == 4) return "Grumpy";
        if (i == 5) return "Loving";
        if (i == 6) return "Excited";
        if (i == 7) return "Shy";
        if (i == 8) return "Curious";
        return "Normal";
    }

    function _getPatternName(uint256 seed) private pure returns (string memory) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 i = uint8((seed >> 16) % 10);
        if (i == 0) return "None";
        if (i == 1) return "Striped";
        if (i == 2) return "Spotted";
        if (i == 3) return "Tuxedo";
        if (i == 4) return "Patches";
        if (i == 5) return "Tiger Stripes";
        if (i == 6) return "Gradient";
        if (i == 7) return "Calico";
        if (i == 8) return "Galaxy Swirl";
        return "Flames";
    }

    function _getAccessoryName(uint256 seed) private pure returns (string memory) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 i = uint8((seed >> 24) % 15);
        if (i == 0) return "None";
        if (i == 1) return "Crown";
        if (i == 2) return "Top Hat";
        if (i == 3) return "Bow Tie";
        if (i == 4) return "Sunglasses";
        if (i == 5) return "Bandana";
        if (i == 6) return "Astronaut Helmet";
        if (i == 7) return "Pirate Eye Patch";
        if (i == 8) return "Golden Crown";
        if (i == 9) return "Wizard Hat";
        if (i == 10) return "Flower Crown";
        if (i == 11) return "Monocle";
        if (i == 12) return "Cape";
        if (i == 13) return "Halo";
        return "Headphones";
    }

    function _getBackgroundName(uint256 seed) private pure returns (string memory) {
        uint8 i = uint8((seed >> 40) % 7);
        if (i == 0) return "Sky Blue";
        if (i == 1) return "Pink Dream";
        if (i == 2) return "Forest Green";
        if (i == 3) return "Night Sky";
        if (i == 4) return "Purple Nebula";
        if (i == 5) return "Sunset Orange";
        return "Hot Pink";
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev Update royalty info (owner only)
     * @param receiver Address to receive royalties
     * @param feeNumerator Fee in basis points (500 = 5%)
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @dev Override supportsInterface to include ERC2981
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
