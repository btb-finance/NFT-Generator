// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";
import {console} from "forge-std/console.sol";

/// @notice Do any two OPOSSUMs come out the same?
///
///         There are two separate questions and they have different answers:
///
///         1. Do two tokens share a SEED? No — the seed hashes the tokenId,
///            which is unique by construction.
///         2. Do two tokens LOOK the same? Yes, and often. The art only reads
///            six small fields out of that 256-bit seed, and those fields have
///            far fewer combinations than the collection has tokens.
///
///         These tests measure both. The visual one is the one that matters:
///         two tokens with different seeds but the same six trait indices
///         render byte-identical SVGs and identical attributes — a buyer
///         cannot tell them apart.
contract UniquenessTest is TestBase {
    /// @dev Trait derivation, mirroring OposNFT/OposRenderer exactly.
    uint256 constant BODY_N = 30;
    uint256 constant EXPRESSION_N = 10;
    uint256 constant PATTERN_N = 10;
    uint256 constant ACCESSORY_N = 15;
    uint256 constant EYE_N = 20;
    uint256 constant BACKGROUND_N = 7;

    /// @dev Every visually distinct opossum the current trait system can make.
    uint256 constant COMBINATIONS =
        BODY_N * EXPRESSION_N * PATTERN_N * ACCESSORY_N * EYE_N * BACKGROUND_N;

    mapping(bytes32 => bool) private seenSeed;
    mapping(uint256 => bool) private seenLook;
    mapping(uint256 => uint256) private lookToSeed;
    mapping(uint256 => bool) private seenCard;

    /// @dev No local model any more: the contract exposes the seed directly,
    ///      so these tests measure the real thing rather than a copy of it.
    /// @dev The six fields the art and the metadata actually read. Two tokens
    ///      agreeing on all six are indistinguishable to a viewer.
    function _look(uint256 seed) internal pure returns (uint256) {
        uint256 body = seed % BODY_N;
        uint256 expression = (seed >> 8) % EXPRESSION_N;
        uint256 pattern = (seed >> 16) % PATTERN_N;
        uint256 accessory = (seed >> 24) % ACCESSORY_N;
        uint256 eye = (seed >> 32) % EYE_N;
        uint256 background = (seed >> 40) % BACKGROUND_N;
        return ((((body * EXPRESSION_N + expression) * PATTERN_N + pattern)
            * ACCESSORY_N + accessory) * EYE_N + eye) * BACKGROUND_N + background;
    }

    // ───────────────────────────────────────────────────────────────────
    // First: prove the model above matches what the contract really mints.
    // Everything after this relies on being able to recompute seeds without
    // paying to mint 88,888 tokens.
    // ───────────────────────────────────────────────────────────────────

    function test_U1_public_seed_matches_what_minting_stores() public {
        uint256[] memory ids = _adminMintAs(200);
        for (uint256 i = 0; i < ids.length; ++i) {
            assertEq(
                nft.tierIndexOf(ids[i]),
                _tierOf(nft.traitSeedOf(ids[i])),
                "traitSeedOf disagrees with the minted token"
            );
        }
    }

    /// @dev Two tokens with the same six trait indices really do produce the
    ///      same picture — this is what makes a "look" collision a duplicate
    ///      rather than a curiosity.
    function test_U2_same_trait_indices_render_identical_art() public {
        // There are no "spare" high bits to vary: `body = seed % 30` and the
        // other fields all fold the whole 256-bit word, so a colliding pair has
        // to be searched for. At 6.3M looks a collision turns up within a few
        // thousand tries, which is itself the point.
        uint256 a;
        uint256 b;
        for (uint256 i = 1; i < 20_000; ++i) {
            uint256 seed = uint256(keccak256(abi.encodePacked("opos-collision", i)));
            uint256 look = _look(seed);
            if (lookToSeed[look] != 0) {
                a = lookToSeed[look];
                b = seed;
                break;
            }
            lookToSeed[look] = seed;
        }

        assertTrue(a != 0 && b != 0, "no colliding pair found in 20,000 draws");
        assertTrue(a != b, "the two seeds must actually differ");
        assertEq(_look(a), _look(b), "same six trait indices");
        assertEq(
            keccak256(bytes(renderer.buildArt(a))),
            keccak256(bytes(renderer.buildArt(b))),
            "identical trait indices must render identical SVG"
        );
    }

    // ───────────────────────────────────────────────────────────────────
    // The two collision questions, across the entire 88,888 supply.
    // ───────────────────────────────────────────────────────────────────

    function test_U3_no_two_tokens_share_a_seed() public {
        uint256 max = nft.MAX_SUPPLY();
        uint256 duplicates;

        vm.pauseGasMetering();
        for (uint256 id = 1; id <= max; ++id) {
            bytes32 key = bytes32(nft.traitSeedOf(id));
            if (seenSeed[key]) duplicates++;
            seenSeed[key] = true;
        }
        vm.resumeGasMetering();

        console.log("seed collisions across the full supply:", duplicates);
        assertEq(duplicates, 0, "two tokens share a seed");
    }

    /// @notice THE ONE THAT MATTERS. Counts how many tokens are visually
    ///         identical to an earlier token across the full 88,888 supply.
    function test_U4_measure_visual_duplicates_across_full_supply() public {
        uint256 max = nft.MAX_SUPPLY();
        uint256 duplicates;

        vm.pauseGasMetering();
        for (uint256 id = 1; id <= max; ++id) {
            uint256 look = _look(nft.traitSeedOf(id));
            if (seenLook[look]) duplicates++;
            seenLook[look] = true;
        }
        vm.resumeGasMetering();

        console.log("distinct looks the trait system can produce:", COMBINATIONS);
        console.log("tokens in the collection:                   ", max);
        console.log("tokens identical to an earlier token:       ", duplicates);

        // Not a statistical bound any more. tokenId -> combination is a
        // bijection, so a single duplicate would mean the permutation is broken.
        assertEq(duplicates, 0, "two tokens render the same picture");
    }

    /// @notice The stricter question: identical ART *and* identical metadata.
    ///         `Generation` is an attribute derived from the token id, so two
    ///         tokens in different generations differ on the trait list even
    ///         when they render the same picture. Within one generation there
    ///         is nothing at all to tell them apart.
    function test_U6_measure_fully_identical_metadata() public {
        uint256 max = nft.MAX_SUPPLY();
        uint256 duplicates;

        vm.pauseGasMetering();
        for (uint256 id = 1; id <= max; ++id) {
            uint256 key = _look(nft.traitSeedOf(id)) * 5 + _generationOf(id);
            if (seenCard[key]) duplicates++;
            seenCard[key] = true;
        }
        vm.resumeGasMetering();

        console.log("tokens whose whole attribute list duplicates an earlier token:", duplicates);
        assertEq(duplicates, 0, "two tokens carry the same attribute list");
    }

    /// @dev Mirrors OposNFT._getGeneration as an index.
    function _generationOf(uint256 tokenId) internal pure returns (uint256) {
        if (tokenId <= 17777) return 0;
        if (tokenId <= 35555) return 1;
        if (tokenId <= 53332) return 2;
        if (tokenId <= 71110) return 3;
        return 4;
    }

    /// @notice How many tokens the collection could hold before a duplicate is
    ///         more likely than not — the classic birthday threshold, ~1.177*sqrt(N).
    function test_U5_report_duplicate_free_headroom() public pure {
        uint256 approxSqrt = _sqrt(COMBINATIONS);
        console.log("distinct looks available:", COMBINATIONS);
        console.log("50/50 chance of a duplicate at about this many mints:", (approxSqrt * 1177) / 1000);
    }

    /// @notice CHARACTERISATION TEST — pins what the tier split ACTUALLY is.
    ///
    ///         OposNFT documents roughly 1/4/10/20/65 percent for
    ///         Mythic/Legendary/Epic/Rare/Common. The real split is nothing
    ///         like that, and it is not caused by the trait permutation: the
    ///         "rare" trait sets are enormous (13 of 30 bodies and 9 of 15
    ///         accessories score points), so a high score is the normal case.
    ///         Uniform random seeds produced the same skew.
    ///
    ///         This matters beyond labelling. Each tier splits 20% of all fees
    ///         among its own members, so a tier with FEWER members pays MORE
    ///         per NFT. With Common the smallest tier and Mythic among the
    ///         largest, per-NFT yield currently runs backwards.
    ///
    ///         Numbers are asserted so the split cannot drift unnoticed while
    ///         the thresholds are being decided.
    function test_U7_rarity_distribution_across_full_supply() public view {
        uint256 max = nft.MAX_SUPPLY();
        uint256[5] memory tiers;

        for (uint256 id = 1; id <= max; ++id) {
            tiers[_tierOf(nft.traitSeedOf(id))]++;
        }

        string[5] memory names = ["Mythic   ", "Legendary", "Epic     ", "Rare     ", "Common   "];
        for (uint256 t = 0; t < 5; ++t) {
            console.log(names[t], tiers[t], (tiers[t] * 10_000) / max); // count, basis points
        }

        assertEq(tiers[0] + tiers[1] + tiers[2] + tiers[3] + tiers[4], max, "every token has a tier");

        // Current reality, to 1% tolerance. NOT the documented targets.
        assertApproxEqAbs((tiers[0] * 10_000) / max, 1388, 100, "Mythic ~13.9% (documented: 1%)");
        assertApproxEqAbs((tiers[1] * 10_000) / max, 2914, 100, "Legendary ~29.1% (documented: 4%)");
        assertApproxEqAbs((tiers[4] * 10_000) / max, 947, 100, "Common ~9.5% (documented: 65%)");

        // The inversion, stated outright: Common is meant to be the biggest
        // tier and currently is the smallest.
        assertLt(tiers[4], tiers[0], "documenting the inversion: fewer Commons than Mythics");
    }

    /// @notice The first tokens minted must not all land in one tier — early
    ///         buyers should see the same spread as everyone else.
    function test_U8_early_tokens_are_not_clustered() public view {
        uint256[5] memory tiers;
        for (uint256 id = 1; id <= 1000; ++id) tiers[_tierOf(nft.traitSeedOf(id))]++;
        for (uint256 t = 0; t < 5; ++t) {
            assertGt(tiers[t], 0, "a tier is missing from the first 1,000 tokens");
        }
        console.log("first 1,000 tokens - Mythic:", tiers[0], "Common:", tiers[4]);
    }

    // ── helpers ──

    /// @dev Mirrors OposNFT._getRarityIndex.
    function _tierOf(uint256 seed) internal pure returns (uint8) {
        uint8 bodyIndex = uint8(seed % 30);
        uint8 accessoryIndex = uint8((seed >> 24) % 15);
        uint8 eyeIndex = uint8((seed >> 32) % 20);
        uint8 patternIndex = uint8((seed >> 16) % 10);

        uint8 score = 0;
        if (bodyIndex == 10 || bodyIndex == 8 || bodyIndex == 19 || bodyIndex >= 27) score += 3;
        else if (bodyIndex == 6 || bodyIndex == 16 || bodyIndex == 17 || bodyIndex == 18 || bodyIndex >= 24) score += 2;

        if (accessoryIndex == 8 || accessoryIndex == 9 || accessoryIndex >= 13) score += 3;
        else if (accessoryIndex == 1 || accessoryIndex == 2 || accessoryIndex == 6 || accessoryIndex == 11 || accessoryIndex == 12) score += 2;

        if (eyeIndex == 2 || eyeIndex == 11 || eyeIndex == 13 || eyeIndex >= 17) score += 1;
        if (patternIndex == 7 || patternIndex == 5 || patternIndex >= 8) score += 1;

        if (score >= 6) return 0;
        if (score >= 4) return 1;
        if (score >= 3) return 2;
        if (score >= 1) return 3;
        return 4;
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
