// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {OposRenderer} from "../../src/OposRenderer.sol";
import {OposNFT} from "../../src/OposNFT.sol";
import {NFTRewardDistributor} from "../../src/NFTRewardDistributor.sol";
import {MockOPOS} from "../mocks/MockOPOS.sol";

/// @notice Shared deployment + fixed-actor pool for every test contract.
///         Inherits from Forge's Test so subclasses get vm/assertEq/etc.
abstract contract TestBase is Test {
    OposRenderer internal renderer;
    OposNFT internal nft;
    NFTRewardDistributor internal distributor;
    MockOPOS internal opos;

    address internal owner = makeAddr("owner");

    /// @notice Fixed pool of actor addresses. Handlers/tests pick by index.
    address[5] internal actors;

    function setUp() public virtual {
        for (uint256 i = 0; i < actors.length; ++i) {
            actors[i] = makeAddr(string.concat("actor", vm.toString(i)));
            vm.deal(actors[i], 100 ether);
        }

        vm.startPrank(owner);
        renderer = new OposRenderer();
        nft = new OposNFT(address(renderer));
        opos = new MockOPOS();
        distributor = new NFTRewardDistributor(address(opos), address(nft));
        nft.setDistributor(address(distributor));
        vm.stopPrank();

        // Default mint price 0.0002 ether — keep but make it cheap to test.
        // Tests that need a specific price can override.
    }

    // ─────────────────────── helpers ───────────────────────

    /// @notice Send `amount` mock-OPOS to the distributor, simulating tax flow.
    function _arriveFee(uint256 amount) internal {
        opos.mintTo(address(distributor), amount);
    }

    /// @notice Mint `amount` NFTs as `to`, by calling buy() with required ETH.
    function _buyAs(address buyer, uint256 amount) internal returns (uint256[] memory ids) {
        uint256 startId = nft.totalSupply() + 1;
        uint256 cost = nft.mintPrice() * amount;
        vm.deal(buyer, cost);
        vm.prank(buyer);
        nft.buy{value: cost}(amount);
        ids = new uint256[](amount);
        for (uint256 i = 0; i < amount; ++i) ids[i] = startId + i;
    }

    /// @notice Mint `amount` NFTs as the owner via adminMint and return ids.
    function _adminMintAs(uint256 amount) internal returns (uint256[] memory ids) {
        uint256 startId = nft.totalSupply() + 1;
        vm.prank(owner);
        nft.adminMint(amount);
        ids = new uint256[](amount);
        for (uint256 i = 0; i < amount; ++i) ids[i] = startId + i;
    }

    /// @notice Sum of all `tierPending` slots.
    function _sumTierPending() internal view returns (uint256 s) {
        for (uint8 t = 0; t < 5; ++t) s += distributor.tierPending(t);
    }

    /// @notice Sum of all `activeInTier` slots.
    function _sumActive() internal view returns (uint256 s) {
        for (uint8 t = 0; t < 5; ++t) s += distributor.activeInTier(t);
    }
}
