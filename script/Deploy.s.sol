// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OposRenderer} from "../src/OposRenderer.sol";
import {OposPalette} from "../src/OposPalette.sol";
import {OposParts} from "../src/OposParts.sol";
import {OposNFT} from "../src/OposNFT.sol";
import {NFTRewardDistributor} from "../src/NFTRewardDistributor.sol";

/// @notice Deploys the OPOSSUM NFT collection + on-chain renderer + reward distributor.
///         After this script runs, the deployer must (separately) call
///         `OPOSSUM.setTreasury(distributor)` on the already-deployed OPOS ERC20
///         and `nft.setDistributor(distributor)` here to wire everything up.
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oposToken = vm.envAddress("OPOS_TOKEN");

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying OposRenderer...");
        OposRenderer renderer = new OposRenderer(address(new OposPalette()), address(new OposParts()));
        console.log("OposRenderer:", address(renderer));

        console.log("Deploying OposNFT...");
        OposNFT nft = new OposNFT(address(renderer));
        console.log("OposNFT:", address(nft));

        console.log("Deploying NFTRewardDistributor...");
        NFTRewardDistributor distributor = new NFTRewardDistributor(oposToken, address(nft), 0, [uint256(0), 0, 0, 0, 0]);
        console.log("NFTRewardDistributor:", address(distributor));

        // Wire the NFT to the distributor so tokenURI shows live yield
        // and ERC-4906 events route correctly.
        nft.setDistributor(address(distributor));

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("OPOS token:         ", oposToken);
        console.log("Renderer:           ", address(renderer));
        console.log("OPOSSUM NFT:        ", address(nft));
        console.log("Reward Distributor: ", address(distributor));
        console.log("==========================");
        console.log("Next step: call OPOSSUM.setTreasury(distributor) on the OPOS ERC20.");
    }
}
