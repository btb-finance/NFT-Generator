// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "../src/PixelCatsRenderer.sol";
import "../src/PixelCatsFullOnChain.sol";

contract DeployBTBCat is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Renderer first
        console.log("Deploying PixelCatsRenderer...");
        PixelCatsRenderer renderer = new PixelCatsRenderer();
        console.log("PixelCatsRenderer deployed at:", address(renderer));

        // Deploy Main Contract with Renderer address
        console.log("Deploying PixelCatsFullOnChainV2...");
        PixelCatsFullOnChainV2 btbCat = new PixelCatsFullOnChainV2(address(renderer));
        console.log("PixelCatsFullOnChainV2 deployed at:", address(btbCat));

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Renderer:", address(renderer));
        console.log("BTB CAT NFT:", address(btbCat));
        console.log("==========================\n");
    }
}
