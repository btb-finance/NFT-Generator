// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";
import {console} from "forge-std/console.sol";
import {OposNFT} from "../../src/OposNFT.sol";
import {MockOPOS} from "../mocks/MockOPOS.sol";
import {NFTRewardDistributor} from "../../src/NFTRewardDistributor.sol";

/// @notice Where mint gas actually goes, so optimisation targets the real cost
///         rather than the obvious-looking one.
contract MintGasTest is TestBase {
    /// @dev A stand-in distributor that accepts the mint notification and does
    ///      nothing. Measuring against it isolates the distributor's share of
    ///      the mint cost from the ERC-721's own.
    function _nftWithNoopDistributor() internal returns (OposNFT freshNft) {
        vm.startPrank(owner);
        freshNft = new OposNFT(address(renderer));
        freshNft.setDistributor(address(new NoopDistributor()));
        vm.stopPrank();
    }

    function test_G1_where_does_mint_gas_go() public {
        uint256[4] memory sizes = [uint256(1), 10, 100, 200];

        console.log("--- adminMint WITH the real distributor ---");
        for (uint256 i = 0; i < sizes.length; ++i) {
            OposNFT n = _freshRealNft();
            vm.prank(owner);
            uint256 g = gasleft();
            n.adminMint(sizes[i]);
            uint256 used = g - gasleft();
            console.log("  amount", sizes[i], "total gas", used);
            console.log("     per token", used / sizes[i]);
        }

        console.log("--- adminMint with a NO-OP distributor (ERC-721 cost only) ---");
        for (uint256 i = 0; i < sizes.length; ++i) {
            OposNFT n = _nftWithNoopDistributor();
            vm.prank(owner);
            uint256 g = gasleft();
            n.adminMint(sizes[i]);
            uint256 used = g - gasleft();
            console.log("  amount", sizes[i], "total gas", used);
            console.log("     per token", used / sizes[i]);
        }
    }

    /// @notice The largest batch buy() advertises. Does it even fit in a block?
    function test_G2_largest_advertised_batch_fits_in_a_block() public {
        OposNFT n = _freshRealNft();
        uint256 cost = n.mintPrice() * 500;
        vm.deal(actors[0], cost);

        vm.prank(actors[0]);
        uint256 g = gasleft();
        n.buy{value: cost}(500);
        uint256 used = g - gasleft();

        console.log("buy(500) total gas:", used);
        console.log("  per token:", used / 500);
        console.log("  Ethereum L1 block limit is ~36,000,000");

        // Not an assertion about correctness — a warning if the maximum batch
        // the contract offers cannot actually be mined on L1.
        if (used > 36_000_000) {
            console.log("  WARNING: exceeds an L1 block. buy(500) is L2-only.");
        }
    }

    /// @dev Fresh NFT + real distributor, wired and ready to mint.
    function _freshRealNft() internal returns (OposNFT freshNft) {
        vm.startPrank(owner);
        freshNft = new OposNFT(address(renderer));
        MockOPOS tok = new MockOPOS();
        NFTRewardDistributor d =
            new NFTRewardDistributor(address(tok), address(freshNft), 0, [uint256(0), 0, 0, 0, 0]);
        freshNft.setDistributor(address(d));
        vm.stopPrank();
    }
}

/// @dev Accepts onMintBatch and returns immediately.
contract NoopDistributor {
    function onMintBatch(uint256[] calldata) external {}
    function pending(uint256) external pure returns (uint256) { return 0; }
    function lifetimeEarned(uint256) external pure returns (uint256) { return 0; }
    function asleep(uint256) external pure returns (bool) { return false; }
}
