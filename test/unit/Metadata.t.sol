// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";
import {Base64Decode} from "../helpers/Base64Decode.sol";
import {MockYieldView} from "../mocks/MockYieldView.sol";
import {OposNFT} from "../../src/OposNFT.sol";
import {OposRenderer} from "../../src/OposRenderer.sol";
import {DeployRenderer} from "../helpers/DeployRenderer.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Metadata surface: what a marketplace actually receives from
///         tokenURI, plus the admin knobs that shape it (renderer, royalty,
///         distributor wiring) and the ERC-165 advertisement that makes
///         marketplaces read royalties and honour metadata refreshes.
contract MetadataTest is TestBase {
    using Base64Decode for string;

    string constant JSON_PREFIX = "data:application/json;base64,";
    string constant SVG_PREFIX = "data:image/svg+xml;base64,";

    /// @dev tokenURI → decoded JSON string.
    function _json(uint256 tokenId) internal view returns (string memory) {
        return Base64Decode.decode(Base64Decode.stripPrefix(nft.tokenURI(tokenId), JSON_PREFIX));
    }

    // ─────────────────── decoded metadata shape ───────────────────

    function test_M1_tokenURI_decodes_to_wellformed_json() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        string memory json = _json(ids[0]);

        assertTrue(json.contains('"name":"OPOSSUM '), "has name");
        assertTrue(json.contains("#1\""), "name carries token id");
        assertTrue(json.contains('"description":"88,888 fully on-chain'), "has description");
        assertTrue(json.contains('"attributes":['), "has attributes array");
        assertTrue(json.contains('"image":"'), "has image");

        // Forge's JSON parser is the real arbiter of "valid JSON" here.
        assertEq(vm.parseJsonString(json, ".description").contains("88,888"), true, "parses as JSON");
    }

    function test_M1_image_is_base64_svg() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        string memory image = vm.parseJsonString(_json(ids[0]), ".image");

        string memory svg = Base64Decode.decode(Base64Decode.stripPrefix(image, SVG_PREFIX));
        assertTrue(svg.contains("<svg"), "decodes to an svg");
        assertTrue(svg.contains("</svg>"), "svg is closed");
    }

    function test_M2_all_trait_types_present() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        string memory json = _json(ids[0]);

        string[11] memory traits = [
            "Rarity", "Generation", "Body", "Eyes", "Expression", "Pattern",
            "Accessory", "Background", "Status", "Claimable OPOS", "Lifetime OPOS"
        ];
        for (uint256 i = 0; i < traits.length; ++i) {
            assertTrue(
                json.contains(string.concat('{"trait_type":"', traits[i], '","value":"')),
                string.concat("missing trait: ", traits[i])
            );
        }

        // Exactly 11, in this order — index 10 is the last one and index 11
        // is absent, so nothing extra slipped into the array.
        assertEq(vm.parseJsonString(json, ".attributes[10].trait_type"), "Lifetime OPOS", "last attribute");
        assertFalse(vm.keyExistsJson(json, ".attributes[11]"), "no 12th attribute");
    }

    function test_M2_rarity_trait_matches_tierIndexOf() public {
        uint256[] memory ids = _buyAs(actors[0], 20);
        string[5] memory tierNames = ["Mythic", "Legendary", "Epic", "Rare", "Common"];

        for (uint256 i = 0; i < ids.length; ++i) {
            string memory json = _json(ids[i]);
            string memory expected = tierNames[nft.tierIndexOf(ids[i])];
            assertEq(vm.parseJsonString(json, ".attributes[0].value"), expected, "rarity trait == tier index");
            // The name is built from the same tier, so it must agree.
            assertTrue(
                json.contains(string.concat('"name":"OPOSSUM ', expected, " #")),
                "name carries the same rarity"
            );
        }
    }

    function test_M3_generation_is_genesis_for_early_ids() public {
        uint256[] memory ids = _buyAs(actors[0], 3);
        for (uint256 i = 0; i < ids.length; ++i) {
            assertEq(vm.parseJsonString(_json(ids[i]), ".attributes[1].value"), "Genesis", "gen 1 = Genesis");
        }
    }

    function test_M4_tokenURI_reverts_for_nonexistent_token() public {
        _buyAs(actors[0], 1);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, uint256(999)));
        nft.tokenURI(999);
    }

    // ─────────────────── yield traits & K/M/B formatting ───────────────────

    /// @dev Fresh NFT wired to a stub distributor so yield values can be dialed
    ///      to display-boundary amounts the real fee flow can't cheaply reach.
    function _nftWithStubYield() internal returns (OposNFT stubNft, MockYieldView view_) {
        vm.startPrank(owner);
        stubNft = new OposNFT(address(renderer));
        view_ = new MockYieldView();
        stubNft.setDistributor(address(view_));
        stubNft.adminMint(1);
        vm.stopPrank();
    }

    function test_M5_yield_amounts_use_K_M_B_suffixes() public {
        (OposNFT stubNft, MockYieldView stub) = _nftWithStubYield();

        uint256[9] memory wholeTokens =
            [uint256(0), 1, 999, 1_000, 1_500, 999_999, 1_000_000, 1_100_000, 2_500_000_000];
        string[9] memory expected =
            ["0", "1", "999", "1K", "1.5K", "999.9K", "1M", "1.1M", "2.5B"];

        for (uint256 i = 0; i < wholeTokens.length; ++i) {
            stub.setYield(wholeTokens[i] * 1e18, wholeTokens[i] * 1e18);
            string memory json =
                Base64Decode.decode(Base64Decode.stripPrefix(stubNft.tokenURI(1), JSON_PREFIX));
            assertEq(
                vm.parseJsonString(json, ".attributes[9].value"), expected[i],
                string.concat("claimable format @ ", vm.toString(wholeTokens[i]))
            );
            assertEq(
                vm.parseJsonString(json, ".attributes[10].value"), expected[i],
                string.concat("lifetime format @ ", vm.toString(wholeTokens[i]))
            );
        }
    }

    function test_M5_fractional_tokens_round_down_to_zero() public {
        (OposNFT stubNft, MockYieldView stub) = _nftWithStubYield();
        // Just under one whole OPOS — displays as "0", not "0.99…".
        stub.setYield(1e18 - 1, 1e18 - 1);
        string memory json = Base64Decode.decode(Base64Decode.stripPrefix(stubNft.tokenURI(1), JSON_PREFIX));
        assertEq(vm.parseJsonString(json, ".attributes[9].value"), "0", "sub-token pending displays 0");
    }

    function test_M6_status_trait_tracks_sleep_state() public {
        (OposNFT stubNft, MockYieldView stub) = _nftWithStubYield();

        string memory json = Base64Decode.decode(Base64Decode.stripPrefix(stubNft.tokenURI(1), JSON_PREFIX));
        assertEq(vm.parseJsonString(json, ".attributes[8].value"), "Active", "awake => Active");

        stub.setAsleep(true);
        json = Base64Decode.decode(Base64Decode.stripPrefix(stubNft.tokenURI(1), JSON_PREFIX));
        assertEq(vm.parseJsonString(json, ".attributes[8].value"), "Asleep", "reaped => Asleep");
    }

    function test_M6_status_flips_to_asleep_after_real_reap() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        assertEq(vm.parseJsonString(_json(ids[0]), ".attributes[8].value"), "Active", "starts Active");

        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        distributor.reap(ids[0]);

        assertEq(vm.parseJsonString(_json(ids[0]), ".attributes[8].value"), "Asleep", "Asleep after reap");
    }

    function test_M7_claimable_trait_matches_pendingReward() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        _arriveFee(5_000 ether);

        // 1 NFT alone in its tier takes that tier's whole 20% share.
        assertEq(nft.pendingReward(ids[0]), 1_000 ether, "pending is 20% of the fee");
        assertEq(vm.parseJsonString(_json(ids[0]), ".attributes[9].value"), "1K", "trait shows 1K");

        vm.prank(actors[0]);
        nft.claim(ids[0]);

        assertEq(vm.parseJsonString(_json(ids[0]), ".attributes[9].value"), "0", "claimable resets");
        assertEq(vm.parseJsonString(_json(ids[0]), ".attributes[10].value"), "1K", "lifetime persists");
    }

    // ─────────────────── tier-scaled effects ───────────────────

    /// @dev Renders a token of each tier and checks the frame treatment steps
    ///      up with rarity: no glow on Common, a glow from Rare, sparkles from
    ///      Epic, and animation only on Mythic.
    function _artForTier(uint8 wanted) internal view returns (string memory) {
        for (uint256 id = 1; id <= 4000; ++id) {
            uint256 seed = nft.traitSeedOf(id);
            if (_tierOfSeed(seed) == wanted) return renderer.buildArt(seed);
        }
        revert("no token of that tier in the first 4,000");
    }

    function _tierOfSeed(uint256 seed) internal pure returns (uint8) {
        uint256 body = seed % 30;
        if (body == 10 || body == 8 || body == 19 || body >= 27) return 0;
        if (body == 6 || body == 16 || body == 17 || body == 18 || body >= 24) return 1;
        if (body == 5 || body == 7 || (body >= 11 && body <= 14)) return 2;
        if (body == 15 || (body >= 20 && body <= 23)) return 3;
        return 4;
    }

    function test_M14_effects_scale_with_rarity() public view {
        string memory common = _artForTier(4);
        assertFalse(common.contains('fill="url(#a)"'), "Common has no aura");
        assertFalse(common.contains("<animate"), "Common does not animate");

        string memory rare = _artForTier(3);
        assertTrue(rare.contains('fill="url(#a)"'), "Rare gains an aura");
        assertFalse(rare.contains("<animate"), "Rare does not animate");

        string memory epic = _artForTier(2);
        assertTrue(epic.contains("#9B30FF"), "Epic aura is purple");

        string memory legendary = _artForTier(1);
        assertTrue(legendary.contains("#FFD700"), "Legendary aura is gold");
        assertFalse(legendary.contains("<animate"), "Legendary does not animate");

        string memory mythic = _artForTier(0);
        assertTrue(mythic.contains("#FF3DDB"), "Mythic aura is magenta");
        assertTrue(mythic.contains("<animate"), "only Mythic animates");
    }

    // ─────────────────── ERC-165 advertisement ───────────────────

    function test_M8_supportsInterface_advertises_expected_standards() public view {
        assertTrue(nft.supportsInterface(0x01ffc9a7), "ERC-165");
        assertTrue(nft.supportsInterface(0x80ac58cd), "ERC-721");
        assertTrue(nft.supportsInterface(0x5b5e139f), "ERC-721Metadata");
        assertTrue(nft.supportsInterface(0x2a55205a), "ERC-2981 royalties");
        assertTrue(nft.supportsInterface(0x49064906), "ERC-4906 metadata update");
        assertFalse(nft.supportsInterface(0xffffffff), "invalid id is false");
        assertFalse(nft.supportsInterface(0xdeadbeef), "unknown id is false");
    }

    // ─────────────────── admin knobs ───────────────────

    function test_M9_setRenderer_swaps_the_art_source() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        string memory before = nft.tokenURI(ids[0]);

        OposRenderer fresh = DeployRenderer.deploy();
        vm.prank(owner);
        nft.setRenderer(address(fresh));

        // A fresh renderer of the same implementation must reproduce the art
        // byte-for-byte — buildArt is pure and seeded only by the token traits.
        assertEq(nft.tokenURI(ids[0]), before, "same implementation => same art");
    }

    function test_M9_setRenderer_rejects_zero_and_non_owner() public {
        vm.prank(owner);
        vm.expectRevert("Renderer cannot be zero");
        nft.setRenderer(address(0));

        vm.prank(actors[0]);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, actors[0]));
        nft.setRenderer(address(renderer));
    }

    function test_M10_setDistributor_rejects_zero_and_post_mint_change() public {
        vm.startPrank(owner);
        OposNFT fresh = new OposNFT(address(renderer));

        vm.expectRevert("Distributor cannot be zero");
        fresh.setDistributor(address(0));

        MockYieldView stub = new MockYieldView();
        fresh.setDistributor(address(stub));
        fresh.adminMint(1);

        // Locked once minting begins: re-pointing would orphan minted tokens'
        // accrued yield.
        MockYieldView replacement = new MockYieldView();
        vm.expectRevert("Cannot change distributor after minting begins");
        fresh.setDistributor(address(replacement));
        vm.stopPrank();
    }

    function test_M10_setDistributor_only_owner() public {
        OposNFT fresh = new OposNFT(address(renderer));
        vm.prank(actors[0]);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, actors[0]));
        fresh.setDistributor(address(distributor));
    }

    function test_M11_royalty_cannot_exceed_five_percent() public {
        vm.prank(owner);
        vm.expectRevert("Royalty cannot exceed 5%");
        nft.setDefaultRoyalty(owner, 501);

        vm.prank(owner);
        nft.setDefaultRoyalty(actors[0], 500); // exactly 5% is allowed
        (address receiver, uint256 amount) = nft.royaltyInfo(1, 10_000);
        assertEq(receiver, actors[0], "receiver updated");
        assertEq(amount, 500, "5% of sale price");
    }

    function test_M12_setMintPrice_updates_price_and_emits() public {
        vm.expectEmit(address(nft));
        emit OposNFT.MintPriceUpdated(1 ether);
        vm.prank(owner);
        nft.setMintPrice(1 ether);

        assertEq(nft.mintPrice(), 1 ether, "price stored");

        // The new price is what buy() actually charges.
        vm.deal(actors[0], 1 ether);
        vm.prank(actors[0]);
        vm.expectRevert("Insufficient ETH sent");
        nft.buy{value: 0.5 ether}(1);
    }

    function test_M12_setMintPrice_only_owner() public {
        vm.prank(actors[0]);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, actors[0]));
        nft.setMintPrice(1 ether);
    }

    // ─────────────────── ERC-4906 hooks ───────────────────

    function test_M13_metadata_update_hooks_are_distributor_only() public {
        vm.prank(actors[0]);
        vm.expectRevert("Not distributor");
        nft.emitMetadataUpdate(1);

        vm.prank(actors[0]);
        vm.expectRevert("Not distributor");
        nft.emitBatchMetadataUpdate();

        // Not even the owner may forge a refresh — only the wired distributor.
        vm.prank(owner);
        vm.expectRevert("Not distributor");
        nft.emitMetadataUpdate(1);
    }

    function test_M13_distributor_can_emit_metadata_updates() public {
        vm.expectEmit(address(nft));
        emit IERC4906.MetadataUpdate(7);
        vm.prank(address(distributor));
        nft.emitMetadataUpdate(7);

        vm.expectEmit(address(nft));
        emit IERC4906.BatchMetadataUpdate(1, nft.MAX_SUPPLY());
        vm.prank(address(distributor));
        nft.emitBatchMetadataUpdate();
    }
}
