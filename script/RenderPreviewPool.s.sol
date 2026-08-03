// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OposRenderer} from "../src/OposRenderer.sol";
import {OposPalette} from "../src/OposPalette.sol";
import {OposParts} from "../src/OposParts.sol";
import {OposNFT} from "../src/OposNFT.sol";
import {NFTRewardDistributor} from "../src/NFTRewardDistributor.sol";

/// @dev Placeholder reward token. The distributor only needs something that
///      answers `balanceOf`; the preview never moves rewards.
contract PreviewToken is ERC20 {
    constructor() ERC20("Preview OPOS", "pOPOS") {}
}

/// @notice Renders a pool of REAL tokenURIs to ./preview/pool.txt, one per
///         line. Deploys the actual OposRenderer + OposNFT + distributor and
///         mints into them, so every byte the preview page displays — art,
///         trait names, rarity tier, yield formatting — is produced by the
///         contracts themselves. The preview page owns no rendering rules and
///         cannot drift from src/.
///
///         Run via scripts/build_preview.sh (which also assembles the HTML).
contract RenderPreviewPool is Script {
    /// @notice Tokens to render. adminMint caps at 200 per call, so this is
    ///         minted in chunks of 200.
    uint256 public constant POOL_SIZE = 200;

    string constant OUT = "./preview/pool.txt";

    /// @dev adminMint uses _safeMint, so this script is the receiving contract.
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function run() external {
        OposRenderer renderer = new OposRenderer(address(new OposPalette()), address(new OposParts()));
        OposNFT nft = new OposNFT(address(renderer));
        PreviewToken token = new PreviewToken();
        NFTRewardDistributor distributor = new NFTRewardDistributor(address(token), address(nft), 0, [uint256(0), 0, 0, 0, 0]);
        nft.setDistributor(address(distributor));

        uint256 remaining = POOL_SIZE;
        while (remaining > 0) {
            uint256 batch = remaining > 200 ? 200 : remaining;
            nft.adminMint(batch);
            remaining -= batch;
        }

        // One tokenURI per line. These are `data:application/json;base64,…`
        // strings — no quotes or newlines — so the line format needs no
        // escaping and the shell can wrap them into a JS array as-is.
        vm.writeFile(OUT, "");
        for (uint256 id = 1; id <= POOL_SIZE; ++id) {
            vm.writeLine(OUT, nft.tokenURI(id));
        }
    }
}
