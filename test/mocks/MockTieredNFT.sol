// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

interface IOnMintBatch {
    function onMintBatch(uint256[] calldata tokenIds) external;
}

/// @notice NFT stand-in with hand-picked tiers and owners. The real OposNFT
///         derives tiers from a random seed, so tests that need "exactly one
///         Mythic and three Commons" can't get there deterministically. This
///         mock also lets a test make the ERC-4906 hooks revert, exercising the
///         distributor's try/catch fallback.
contract MockTieredNFT {
    mapping(uint256 => address) public owners;
    mapping(uint256 => uint8) public tiers;

    IOnMintBatch public distributor;
    bool public hooksRevert;

    function setDistributor(address d) external {
        distributor = IOnMintBatch(d);
    }

    function setHooksRevert(bool v) external {
        hooksRevert = v;
    }

    /// @notice Register `tokenIds` with the distributor at the given tiers.
    function mint(uint256[] calldata tokenIds, address to, uint8 tier) external {
        for (uint256 i; i < tokenIds.length; ++i) {
            owners[tokenIds[i]] = to;
            tiers[tokenIds[i]] = tier;
        }
        distributor.onMintBatch(tokenIds);
    }

    function transfer(uint256 tokenId, address to) external {
        owners[tokenId] = to;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return owners[tokenId];
    }

    function tierIndexOf(uint256 tokenId) external view returns (uint8) {
        return tiers[tokenId];
    }

    // ── ERC-4906 hooks the distributor calls through try/catch ──
    function emitMetadataUpdate(uint256) external view {
        require(!hooksRevert, "hook down");
    }

    function emitBatchMetadataUpdate() external view {
        require(!hooksRevert, "hook down");
    }
}
