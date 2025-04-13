// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BTBFinanceNFT is ERC721, ERC721Enumerable, ERC2981, Ownable, ReentrancyGuard {
    // Start token ID from 1 instead of 0
    uint256 private _nextTokenId = 1;
    
    // Maximum supply of NFTs
    uint256 public constant MAX_SUPPLY = 10000;
    
    // Base URI for metadata
    string private _baseTokenURI;
    
    // BTB token contract
    IERC20 public btbToken;
    
    // Price per NFT in BTB tokens
    uint256 public pricePerNFT;
    
    // Flag to check if payment token is set
    bool private _isPaymentTokenSet;
    
    constructor(address initialOwner)
        ERC721("Pixel Avatars", "AVTR")
        Ownable(initialOwner)
    {
        // Initialize with IPFS metadata URI
        _baseTokenURI = "ipfs://bafybeihrssqtzq5abo3l2527tt4m5zjle4v5irvtsjiq77reycc5khh77y/";
        
        // Set default royalty to 5% to the contract creator
        _setDefaultRoyalty(initialOwner, 500); // 500 = 5%
    }
    
    /**
     * @dev Sets the BTB token address and price
     */
    function setPaymentToken(address _btbToken, uint256 _pricePerNFT) public onlyOwner {
        btbToken = IERC20(_btbToken);
        pricePerNFT = _pricePerNFT;
        _isPaymentTokenSet = true;
    }
    
    /**
     * @dev Updates the royalty information for the collection
     * @param receiver Address that should receive royalties
     * @param feeNumerator Fee to be paid (in basis points, so 100 = 1%)
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) public onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }
    
    /**
     * @dev Removes default royalty information
     */
    function deleteDefaultRoyalty() public onlyOwner {
        _deleteDefaultRoyalty();
    }
    
    /**
     * @dev Sets token-specific royalty information
     * @param tokenId The token ID to set royalty for
     * @param receiver Address that should receive royalties
     * @param feeNumerator Fee to be paid (in basis points, so 100 = 1%)
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) public onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }
    
    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`.
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
    
    /**
     * @dev Sets the base URI for all token IDs. It is automatically
     * added as a prefix to the token ID to obtain the tokenURI.
     * If there is no base URI, the tokenURI is tokenID.toString().
     */
    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }
    
    /**
     * @dev Update the price per NFT
     */
    function setPricePerNFT(uint256 _newPrice) public onlyOwner {
        pricePerNFT = _newPrice;
    }
    
    /**
     * @dev See {IERC721-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, _toString(tokenId), ".json")) : "";
    }
    
    /**
     * @dev Helper function to convert uint256 to string
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        // This is just a simple implementation of uint256 to string
        if (value == 0) {
            return "0";
        }
        
        uint256 temp = value;
        uint256 digits;
        
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
    
    /**
     * @dev Returns whether `tokenId` exists.
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return ownerOf(tokenId) != address(0);
    }
    
    /**
     * @dev Mint a single NFT (admin only)
     */
    function safeMint(address to) public onlyOwner returns (uint256) {
        require(_nextTokenId <= MAX_SUPPLY, "Max supply reached");
        
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }
    
    /**
     * @dev Batch mint multiple NFTs (admin only)
     */
    function batchMint(address to, uint256 amount) public onlyOwner returns (uint256[] memory) {
        require(_nextTokenId + amount - 1 <= MAX_SUPPLY, "Would exceed max supply");
        
        uint256[] memory tokenIds = new uint256[](amount);
        
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _nextTokenId++;
            _safeMint(to, tokenId);
            tokenIds[i] = tokenId;
        }
        
        return tokenIds;
    }
    
    /**
     * @dev Airdrop NFTs to multiple recipients (admin only)
     * @param recipients Array of addresses to receive NFTs
     * @return tokenIds Array of minted token IDs
     */
    function airdropNFTs(address[] calldata recipients) public onlyOwner returns (uint256[] memory) {
        uint256 recipientCount = recipients.length;
        require(recipientCount > 0, "No recipients provided");
        require(_nextTokenId + recipientCount - 1 <= MAX_SUPPLY, "Would exceed max supply");
        
        uint256[] memory tokenIds = new uint256[](recipientCount);
        
        for (uint256 i = 0; i < recipientCount; i++) {
            require(recipients[i] != address(0), "Cannot mint to zero address");
            
            uint256 tokenId = _nextTokenId++;
            _safeMint(recipients[i], tokenId);
            tokenIds[i] = tokenId;
        }
        
        return tokenIds;
    }
    
    /**
     * @dev Allow users to buy NFTs with BTB tokens
     * User just needs to enter the amount of NFTs they want to buy
     */
    function buyNFT(uint256 amount) public nonReentrant returns (uint256[] memory) {
        require(_isPaymentTokenSet, "Payment token not set");
        require(amount > 0, "Must buy at least 1 NFT");
        require(_nextTokenId + amount - 1 <= MAX_SUPPLY, "Would exceed max supply");
        
        uint256 totalPrice = pricePerNFT * amount;
        
        // Transfer BTB tokens from buyer to contract
        require(btbToken.transferFrom(msg.sender, address(this), totalPrice), "BTB token transfer failed");
        
        // Mint NFTs to buyer
        uint256[] memory tokenIds = new uint256[](amount);
        
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _nextTokenId++;
            _safeMint(msg.sender, tokenId);
            tokenIds[i] = tokenId;
        }
        
        return tokenIds;
    }
    
    /**
     * @dev Withdraw BTB tokens from contract (admin only)
     */
    function withdrawTokens(address to, uint256 amount) public onlyOwner nonReentrant {
        require(_isPaymentTokenSet, "Payment token not set");
        require(btbToken.transfer(to, amount), "Token transfer failed");
    }
    
    /**
     * @dev Get current price in BTB tokens
     */
    function getPrice(uint256 amount) public view returns (uint256) {
        return pricePerNFT * amount;
    }
    
    /**
     * @dev Get total minted NFTs
     */
    function totalMinted() public view returns (uint256) {
        return _nextTokenId - 1;
    }
    
    /**
     * @dev Get remaining NFTs that can be minted
     */
    function remainingSupply() public view returns (uint256) {
        return MAX_SUPPLY - (_nextTokenId - 1);
    }
    
    // The following functions are overrides required by Solidity.
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }
    
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}