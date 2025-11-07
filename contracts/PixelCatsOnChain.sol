// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title PixelCatsOnChain
 * @dev Fully on-chain generative Pixel Cats NFT
 * All images and metadata are generated and stored on-chain
 */
contract PixelCatsOnChain is ERC721, Ownable {
    using Strings for uint256;

    uint256 private _tokenIdCounter;
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public mintPrice = 0.01 ether;

    // Store traits as packed uint256 (saves massive gas)
    mapping(uint256 => uint256) private tokenTraits;

    // Trait arrays
    string[10] private backgrounds = ["Sky Blue", "Sunset Orange", "Forest Green", "Deep Purple", "Pink Dream", "Galaxy Black", "Golden Hour", "Cyber Neon", "Rainbow", "Cosmic Void"];
    string[11] private bodyColors = ["Orange Tabby", "Black", "White", "Gray", "Calico", "Siamese", "Blue Russian", "Golden", "Pink Bubblegum", "Cyber Chrome", "Rainbow Holographic"];
    string[9] private eyeColors = ["Green", "Blue", "Yellow", "Brown", "Amber", "Heterochromia", "Red Laser", "Diamond White", "Galaxy"];
    string[12] private accessories = ["None", "Bow Tie", "Collar", "Sunglasses", "Crown", "Top Hat", "Bandana", "Pirate Eye Patch", "VR Headset", "Laser Eyes", "Astronaut Helmet", "Golden Crown"];
    string[10] private expressions = ["Happy", "Sleepy", "Grumpy", "Surprised", "Winking", "Loving", "Mischievous", "Derpy", "Cool", "Alien"];
    string[10] private patterns = ["Solid", "Striped", "Spotted", "Tuxedo", "Patches", "Tiger Stripes", "Leopard Spots", "Glitch", "Pixel Matrix", "Cosmic Swirl"];

    // Color mappings
    mapping(uint8 => string) private backgroundColors;
    mapping(uint8 => string) private bodyColorCodes;
    mapping(uint8 => string) private eyeColorCodes;

    event CatMinted(uint256 indexed tokenId, uint256 traits);

    constructor() ERC721("Pixel Cats On Chain", "PXCAT") Ownable(msg.sender) {
        _initializeColors();
    }

    function _initializeColors() private {
        // Background colors
        backgroundColors[0] = "#87CEEB";
        backgroundColors[1] = "#FF6B35";
        backgroundColors[2] = "#228B22";
        backgroundColors[3] = "#4B0082";
        backgroundColors[4] = "#FFB6C1";
        backgroundColors[5] = "#0D0221";
        backgroundColors[6] = "#FFD700";
        backgroundColors[7] = "#00FFFF";
        backgroundColors[8] = "#FF69B4";
        backgroundColors[9] = "#000000";

        // Body colors
        bodyColorCodes[0] = "#FF8C42";
        bodyColorCodes[1] = "#2C2C2C";
        bodyColorCodes[2] = "#F5F5F5";
        bodyColorCodes[3] = "#808080";
        bodyColorCodes[4] = "#FF8C42";
        bodyColorCodes[5] = "#D4A574";
        bodyColorCodes[6] = "#6495ED";
        bodyColorCodes[7] = "#FFD700";
        bodyColorCodes[8] = "#FF69B4";
        bodyColorCodes[9] = "#C0C0C0";
        bodyColorCodes[10] = "#FF00FF";

        // Eye colors
        eyeColorCodes[0] = "#00FF00";
        eyeColorCodes[1] = "#0000FF";
        eyeColorCodes[2] = "#FFFF00";
        eyeColorCodes[3] = "#8B4513";
        eyeColorCodes[4] = "#FFBF00";
        eyeColorCodes[5] = "#00FF00";
        eyeColorCodes[6] = "#FF0000";
        eyeColorCodes[7] = "#FFFFFF";
        eyeColorCodes[8] = "#9370DB";
    }

    /**
     * @dev Mint a new Pixel Cat with pseudo-random traits
     */
    function mint() external payable {
        require(_tokenIdCounter < MAX_SUPPLY, "Max supply reached");
        require(msg.value >= mintPrice, "Insufficient payment");

        uint256 tokenId = _tokenIdCounter++;

        // Generate pseudo-random traits
        uint256 traits = _generateTraits(tokenId);
        tokenTraits[tokenId] = traits;

        _safeMint(msg.sender, tokenId);
        emit CatMinted(tokenId, traits);
    }

    /**
     * @dev Owner mint for airdrops
     */
    function ownerMint(address to, uint256 count) external onlyOwner {
        require(_tokenIdCounter + count <= MAX_SUPPLY, "Exceeds max supply");

        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = _tokenIdCounter++;
            uint256 traits = _generateTraits(tokenId);
            tokenTraits[tokenId] = traits;
            _safeMint(to, tokenId);
            emit CatMinted(tokenId, traits);
        }
    }

    /**
     * @dev Generate pseudo-random traits packed into uint256
     */
    function _generateTraits(uint256 tokenId) private view returns (uint256) {
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            tokenId,
            msg.sender
        )));

        uint8 background = uint8(randomSeed % backgrounds.length);
        uint8 bodyColor = uint8((randomSeed >> 8) % bodyColors.length);
        uint8 eyeColor = uint8((randomSeed >> 16) % eyeColors.length);
        uint8 accessory = uint8((randomSeed >> 24) % accessories.length);
        uint8 expression = uint8((randomSeed >> 32) % expressions.length);
        uint8 pattern = uint8((randomSeed >> 40) % patterns.length);

        // Pack traits into single uint256
        return uint256(background) << 40 |
               uint256(bodyColor) << 32 |
               uint256(eyeColor) << 24 |
               uint256(accessory) << 16 |
               uint256(expression) << 8 |
               uint256(pattern);
    }

    /**
     * @dev Get token URI with on-chain SVG and metadata
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");

        uint256 traits = tokenTraits[tokenId];

        string memory svg = _generateSVG(tokenId, traits);
        string memory json = _generateMetadata(tokenId, traits, svg);

        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        ));
    }

    /**
     * @dev Generate SVG image on-chain
     */
    function _generateSVG(uint256 tokenId, uint256 traits) private view returns (string memory) {
        (uint8 bg, uint8 body, uint8 eyes, uint8 acc, uint8 expr, uint8 pat) = _unpackTraits(traits);

        string memory bgColor = backgroundColors[bg];
        string memory bodyColor = bodyColorCodes[body];
        string memory eyeColor = eyeColorCodes[eyes];

        // Generate simplified on-chain SVG (full complexity would be very expensive)
        return string(abi.encodePacked(
            '<svg width="480" height="480" xmlns="http://www.w3.org/2000/svg">',
            '<rect width="480" height="480" fill="', bgColor, '"/>',
            '<text x="240" y="240" font-size="20" text-anchor="middle" fill="white">',
            'Pixel Cat #', tokenId.toString(),
            '</text>',
            '<text x="240" y="270" font-size="14" text-anchor="middle" fill="white">',
            bodyColors[body], ' - ', expressions[expr],
            '</text>',
            '</svg>'
        ));
    }

    /**
     * @dev Generate metadata JSON
     */
    function _generateMetadata(uint256 tokenId, uint256 traits, string memory svg) private view returns (string memory) {
        (uint8 bg, uint8 body, uint8 eyes, uint8 acc, uint8 expr, uint8 pat) = _unpackTraits(traits);

        return string(abi.encodePacked(
            '{',
            '"name":"Pixel Cat #', tokenId.toString(), '",',
            '"description":"Fully on-chain generative pixel art cat",',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '",',
            '"attributes":[',
            '{"trait_type":"Background","value":"', backgrounds[bg], '"},',
            '{"trait_type":"Body Color","value":"', bodyColors[body], '"},',
            '{"trait_type":"Eye Color","value":"', eyeColors[eyes], '"},',
            '{"trait_type":"Accessory","value":"', accessories[acc], '"},',
            '{"trait_type":"Expression","value":"', expressions[expr], '"},',
            '{"trait_type":"Pattern","value":"', patterns[pat], '"}',
            ']}'
        ));
    }

    /**
     * @dev Unpack traits from uint256
     */
    function _unpackTraits(uint256 traits) private pure returns (
        uint8 background,
        uint8 bodyColor,
        uint8 eyeColor,
        uint8 accessory,
        uint8 expression,
        uint8 pattern
    ) {
        background = uint8((traits >> 40) & 0xFF);
        bodyColor = uint8((traits >> 32) & 0xFF);
        eyeColor = uint8((traits >> 24) & 0xFF);
        accessory = uint8((traits >> 16) & 0xFF);
        expression = uint8((traits >> 8) & 0xFF);
        pattern = uint8(traits & 0xFF);
    }

    /**
     * @dev Get traits for a token
     */
    function getTraits(uint256 tokenId) external view returns (
        string memory background,
        string memory bodyColor,
        string memory eyeColor,
        string memory accessory,
        string memory expression,
        string memory pattern
    ) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");

        uint256 traits = tokenTraits[tokenId];
        (uint8 bg, uint8 body, uint8 eyes, uint8 acc, uint8 expr, uint8 pat) = _unpackTraits(traits);

        return (
            backgrounds[bg],
            bodyColors[body],
            eyeColors[eyes],
            accessories[acc],
            expressions[expr],
            patterns[pat]
        );
    }

    /**
     * @dev Update mint price
     */
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    /**
     * @dev Withdraw contract balance
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev Get total minted
     */
    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
