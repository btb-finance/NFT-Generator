// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.6.0
pragma solidity ^0.8.34;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

interface IOposRenderer {
    function buildArt(uint256 seed) external pure returns (string memory);
}

interface IRewardDistributorView {
    function pending(uint256 tokenId) external view returns (uint256);
    function lifetimeEarned(uint256 tokenId) external view returns (uint256);
}

interface IRewardDistributorMint {
    function onMintBatch(uint256[] calldata tokenIds) external;
}

/**
 * @title OposNFT
 * @dev OPOSSUM-ecosystem NFT collection. Fully on-chain SVG art via OposRenderer,
 *      ERC-2981 royalties for marketplaces, ERC-4906 metadata-update events for
 *      live yield display, and per-token OPOS yield via the NFTRewardDistributor.
 */
contract OposNFT is ERC721, ERC2981, IERC4906, Ownable {
    using Strings for uint256;

    uint256 private _tokenIdCounter = 1; // Start from 1, not 0
    mapping(uint256 => uint256) private tokenTraits;
    IOposRenderer public renderer;

    /// @notice Distributor contract that holds OPOS rewards and tracks per-NFT yield.
    ///         Set after deployment via setDistributor.
    IRewardDistributorView public distributor;

    // Supply and pricing
    uint256 public constant MAX_SUPPLY = 88888;
    uint256 public mintPrice = 0.0002 ether; // Default price, can be updated

    // Events
    event MintPriceUpdated(uint256 newPrice);
    event NFTPurchased(address indexed buyer, uint256 amount, uint256 totalCost);
    event DistributorUpdated(address indexed oldDistributor, address indexed newDistributor);

    constructor(address _renderer) ERC721("OPOSSUM NFT", "OPOSN") Ownable(msg.sender) {
        renderer = IOposRenderer(_renderer);
        // Set 5% royalty fee to contract owner
        _setDefaultRoyalty(msg.sender, 500); // 500 basis points = 5%
    }

    function setRenderer(address _renderer) external onlyOwner {
        renderer = IOposRenderer(_renderer);
    }

    /**
     * @dev Wire up the OPOS reward distributor. Once set, `tokenURI` will display
     *      claimable + lifetime OPOS as integer traits, and the distributor may
     *      emit ERC-4906 metadata-update events through this contract.
     */
    function setDistributor(address _distributor) external onlyOwner {
        address old = address(distributor);
        distributor = IRewardDistributorView(_distributor);
        emit DistributorUpdated(old, _distributor);
        emit BatchMetadataUpdate(1, MAX_SUPPLY);
    }

    /// @dev Distributor-only proxy so it can signal a single-token metadata refresh.
    function emitMetadataUpdate(uint256 tokenId) external {
        require(msg.sender == address(distributor), "Not distributor");
        emit MetadataUpdate(tokenId);
    }

    /// @dev Distributor-only proxy for full-collection metadata refresh.
    function emitBatchMetadataUpdate() external {
        require(msg.sender == address(distributor), "Not distributor");
        emit BatchMetadataUpdate(1, MAX_SUPPLY);
    }

    /**
     * @dev Set the mint price (admin only)
     * @param _price New price in wei
     */
    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
        emit MintPriceUpdated(_price);
    }

    /**
     * @dev Admin mint - FREE minting for owner only
     * @param amount Number of NFTs to mint (max 200 per transaction)
     */
    function adminMint(uint256 amount) external onlyOwner {
        require(amount > 0 && amount <= 200, "Amount must be 1-200");
        require(_tokenIdCounter + amount <= MAX_SUPPLY, "Exceeds max supply");

        uint256[] memory ids = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter++;
            uint256 traits = _generateTraits(tokenId);
            tokenTraits[tokenId] = traits;
            ids[i] = tokenId;
            _safeMint(msg.sender, tokenId);
        }
        _notifyDistributor(ids);
    }

    /**
     * @dev Public buy function - Users buy NFTs with ETH
     * @param amount Number of NFTs to buy (max 500 per transaction)
     */
    function buy(uint256 amount) external payable {
        require(amount > 0 && amount <= 500, "Amount must be 1-500");
        require(_tokenIdCounter + amount <= MAX_SUPPLY, "Exceeds max supply");

        uint256 totalCost = mintPrice * amount;
        require(msg.value >= totalCost, "Insufficient ETH sent");

        uint256[] memory ids = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter++;
            uint256 traits = _generateTraits(tokenId);
            tokenTraits[tokenId] = traits;
            ids[i] = tokenId;
            _safeMint(msg.sender, tokenId);
        }
        _notifyDistributor(ids);

        emit NFTPurchased(msg.sender, amount, totalCost);

        // Refund excess ETH
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
    }

    /**
     * @dev Tells the distributor about freshly-minted tokenIds so it can
     *      checkpoint per-tier reward indices. Skipped if distributor is unset.
     */
    function _notifyDistributor(uint256[] memory ids) private {
        IRewardDistributorView dist = distributor;
        if (address(dist) == address(0)) return;
        IRewardDistributorMint(address(dist)).onMintBatch(ids);
    }

    /**
     * @dev Public tier index for a tokenId: 0=Mythic, 1=Legendary, 2=Epic,
     *      3=Rare, 4=Common. The distributor reads this to route rewards.
     */
    function tierIndexOf(uint256 tokenId) external view returns (uint8) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return _getRarityIndex(tokenTraits[tokenId]);
    }

    /**
     * @dev Withdraw collected ETH (admin only)
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }

    function _generateTraits(uint256 tokenId) private view returns (uint256) {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, tokenId, msg.sender, block.prevrandao)));
        return seed;
    }

    /**
     * @dev Build the on-chain JSON metadata: SVG image + traits + live OPOS yield.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");

        string memory svg = renderer.buildArt(tokenTraits[tokenId]);
        string memory rarity = _getRarityTier(tokenTraits[tokenId]);
        string memory json = string(abi.encodePacked(
            '{"name":"OPOSSUM ', rarity, ' #', tokenId.toString(), '",',
            '"description":"88,888 fully on-chain OPOSSUM NFTs. Every holder earns a 1/88,888 share of every OPOS transfer tax in real time, claimable on demand.",',
            '"attributes":[',
            _getAttributes(tokenTraits[tokenId]),
            ',',
            _getYieldAttributes(tokenId),
            '],',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        ));

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /**
     * @dev Builds the two OPOS yield traits as numeric (decimal-stripped) values.
     *      Returns "0" for both if no distributor is wired up yet, so the
     *      attribute shape stays stable across the contract's lifetime.
     */
    function _getYieldAttributes(uint256 tokenId) private view returns (string memory) {
        uint256 claimable;
        uint256 lifetime;
        IRewardDistributorView dist = distributor;
        if (address(dist) != address(0)) {
            // Strip 18 decimals — display whole OPOS units only.
            claimable = dist.pending(tokenId) / 1e18;
            lifetime = dist.lifetimeEarned(tokenId) / 1e18;
        }
        return string(abi.encodePacked(
            '{"display_type":"number","trait_type":"Claimable OPOS","value":', claimable.toString(), '},',
            '{"display_type":"number","trait_type":"Lifetime OPOS","value":', lifetime.toString(), '}'
        ));
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
     * Genesis: 0-17,777 (20% = first 17,777 NFTs)
     * Alpha: 17,778-35,555 (20% = next 17,777 NFTs)
     * Beta: 35,556-53,332 (20% = next 17,777 NFTs)
     * Gamma: 53,333-71,110 (20% = next 17,777 NFTs)
     * Delta: 71,111-88,888 (20% = last 17,778 NFTs)
     */
    function _getGeneration() private view returns (string memory) {
        uint256 supply = _tokenIdCounter;
        if (supply <= 17777) return "Genesis";
        if (supply <= 35555) return "Alpha";
        if (supply <= 53332) return "Beta";
        if (supply <= 71110) return "Gamma";
        return "Delta";
    }

    /**
     * @dev Calculate rarity tier based on trait combinations
     * Out of 88,888 total supply:
     * Mythic: ~1% (~889 NFTs) - Golden Crown/Wizard Hat + Rainbow/Chrome/Rose Gold body
     * Legendary: ~4% (~3,556 NFTs) - Golden Crown, Wizard Hat, or rare body colors
     * Epic: ~10% (~8,889 NFTs) - Multiple rare traits
     * Rare: ~20% (~17,778 NFTs) - At least one rare trait
     * Common: ~65% (~57,777 NFTs) - Standard traits
     */
    function _getRarityTier(uint256 seed) private pure returns (string memory) {
        uint8 idx = _getRarityIndex(seed);
        if (idx == 0) return "Mythic";
        if (idx == 1) return "Legendary";
        if (idx == 2) return "Epic";
        if (idx == 3) return "Rare";
        return "Common";
    }

    /**
     * @dev Returns the tier index from a trait seed: 0=Mythic, 1=Legendary,
     *      2=Epic, 3=Rare, 4=Common. Mirrors the score logic in `_getRarityTier`.
     */
    function _getRarityIndex(uint256 seed) private pure returns (uint8) {
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

        // Determine tier index based on score
        if (rarityScore >= 6) return 0;  // Mythic     (~1%  = ~889 NFTs)
        if (rarityScore >= 4) return 1;  // Legendary  (~4%  = ~3,556 NFTs)
        if (rarityScore >= 3) return 2;  // Epic       (~10% = ~8,889 NFTs)
        if (rarityScore >= 1) return 3;  // Rare       (~20% = ~17,778 NFTs)
        return 4;                         // Common     (~65% = ~57,776 NFTs)
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
        override(ERC721, ERC2981, IERC165)
        returns (bool)
    {
        // 0x49064906 = ERC-4906 (MetadataUpdate / BatchMetadataUpdate).
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }
}
