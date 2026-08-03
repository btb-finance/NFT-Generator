// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

interface IOposPalette {
    function backgroundColor(uint256 seed) external pure returns (string memory);
    function bodyColor(uint256 seed) external pure returns (string memory);
    function eyeColor(uint256 seed) external pure returns (string memory);
}

interface IOposParts {
    function drawBase(string memory bodyColor) external pure returns (string memory);
    function drawFace() external pure returns (string memory);
    function drawVolume() external pure returns (string memory);
    function drawEyes(uint8 expression, string memory eyeColor) external pure returns (string memory);
    function drawPattern(uint8 pattern, string memory shade) external pure returns (string memory);
    function drawAccessory(uint8 accessory, string memory eyeColor) external pure returns (string memory);
}

/**
 * @title OposRenderer
 * @dev Pure-function on-chain SVG renderer for the OPOSSUM NFT collection.
 *      24x24 pixel grid scaled to 480x480; each "pixel" is a 20x20 SVG rect.
 *      Trait selection (body color, eye color, expression, pattern, accessory,
 *      background) is derived from the seed in the same bit ranges the NFT
 *      contract uses for trait names, so visual + textual traits stay in sync.
 *
 *      SIZE: the collection's art does not fit in one contract — a single
 *      renderer compiled to ~39KB against EIP-170's 24,576-byte limit, so it
 *      could never be deployed. The colour tables live in OposPalette and the
 *      expression/pattern/accessory tables in OposParts, each with its own
 *      byte budget. `buildArt` is a view path reached through eth_call, so the
 *      cross-contract calls cost holders nothing.
 */
contract OposRenderer {
    using Strings for uint256;

    // ───────────── Tier-scaled effects ─────────────
    // Each tier should look better than the one below it, so the frame itself
    // is graded: Common gets nothing, Rare a coloured aura, Epic adds sparkles,
    // Legendary more of both, Mythic a gold animated field. The tier is read
    // off the body colour — OposNFT gives each tier its own disjoint body pool,
    // so the body identifies the tier.

    /// @dev 3 bits per body id -> tier. Mirrors OposNFT.BODY_TIER.
    uint256 private constant BODY_TIER =
        0x00000000000000000000000000000000000000000000496db049692420454924;

    /// @dev 12 sparkle positions on the 48x48 grid (6 bits x, then 6 bits y),
    ///      all clear of the character. Each tier takes a prefix of the list.
    uint256 private constant SPARKLES =
        0x000000000000000000000000000092e242aa89c766d5423e930686b7841ac103;

    IOposPalette public immutable PALETTE;
    IOposParts public immutable PARTS;

    constructor(address palette, address parts) {
        PALETTE = IOposPalette(palette);
        PARTS = IOposParts(parts);
    }

    /// @dev Translucent black: patterns darken whatever fur is beneath them,
    ///      so stripes and spots read as a shade of the body colour rather than
    ///      a fixed tone that clashes with 29 of the 30 bodies.
    string private constant SHADE = "rgba(0,0,0,0.28)";

    /// @notice Build the complete on-chain SVG for a tokenId given its trait seed.
    function buildArt(uint256 seed) external view returns (string memory) {
        uint8 tier = _tierOf(seed);
        string memory pixels = string(abi.encodePacked(_drawOpossum(seed), _sparkleField(tier)));
        string memory bgColor = PALETTE.backgroundColor(seed);

        return string(abi.encodePacked(
            // viewBox is what lets consumers scale the art. Without it a
            // marketplace or wallet that sets its own width/height CLIPS the
            // image instead of resizing it.
            '<svg width="480" height="480" viewBox="0 0 480 480" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">',
            _defs(tier),
            '<rect width="480" height="480" fill="', bgColor, '"/>',
            // Spotlight behind the character: lifts it off a flat colour field.
            '<rect width="480" height="480" fill="url(#s)"/>',
            // Tier glow, behind the character.
            _aura(tier),
            // Soft contact shadow so the character sits on something instead of
            // floating. `shape-rendering="auto"` overrides the SVG-wide
            // crispEdges just for this one ellipse — everything else stays
            // hard-edged pixel art.
            '<ellipse cx="240" cy="428" rx="118" ry="17" fill="url(#d)" shape-rendering="auto"/>',
            // Nothing translucent is ever painted OVER the pixels — the
            // spotlight and contact shadow sit behind them — so the art keeps
            // its hard pixel edges at full contrast.
            pixels,
            '</svg>'
        ));
    }

    /**
     * @dev Lighting gradients. Both are neutral white/black over whatever
     *      background colour was rolled, so one definition works for all seven
     *      backgrounds without a per-colour palette. `shape-rendering` only
     *      affects edge antialiasing, so the gradients stay smooth while the
     *      pixel rects stay crisp.
     */
    function _defs(uint8 tier) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<defs>',
            '<radialGradient id="s" cx="50%" cy="42%" r="60%">',
            '<stop offset="0%" stop-color="#fff" stop-opacity="0.30"/>',
            '<stop offset="100%" stop-color="#fff" stop-opacity="0"/>',
            '</radialGradient>',
            '<radialGradient id="d" cx="50%" cy="50%" r="50%">',
            '<stop offset="0%" stop-color="#000" stop-opacity="0.34"/>',
            '<stop offset="100%" stop-color="#000" stop-opacity="0"/>',
            '</radialGradient>',
            _auraGradient(tier),
            '</defs>'
        ));
    }

    /// @dev Tier index from a trait seed: 0 = Mythic .. 4 = Common.
    function _tierOf(uint256 seed) private pure returns (uint8) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint8((BODY_TIER >> ((seed % 30) * 3)) & 0x7);
    }

    /// @dev Colour and strength of the glow behind the character. Common has
    ///      none; each step up is brighter and a richer colour.
    function _auraGradient(uint8 tier) private pure returns (string memory) {
        if (tier > 3) return "";
        string memory colour = "#1E90FF";   // Rare - blue
        string memory strength = "0.30";
        if (tier == 2) { colour = "#9B30FF"; strength = "0.38"; }  // Epic - purple
        if (tier == 1) { colour = "#FFD700"; strength = "0.46"; }  // Legendary - gold
        if (tier == 0) { colour = "#FF3DDB"; strength = "0.55"; }  // Mythic - magenta
        return string(abi.encodePacked(
            '<radialGradient id="a" cx="50%" cy="48%" r="52%">',
            '<stop offset="35%" stop-color="', colour, '" stop-opacity="', strength, '"/>',
            '<stop offset="100%" stop-color="', colour, '" stop-opacity="0"/>',
            '</radialGradient>'
        ));
    }

    /// @dev The glow itself, painted behind the opossum. Mythic breathes.
    function _aura(uint8 tier) private pure returns (string memory) {
        if (tier > 3) return "";
        if (tier == 0) {
            return '<circle cx="240" cy="230" r="230" fill="url(#a)" shape-rendering="auto">'
                '<animate attributeName="opacity" values="1;0.55;1" dur="3s" repeatCount="indefinite"/>'
                '</circle>';
        }
        return '<circle cx="240" cy="230" r="230" fill="url(#a)" shape-rendering="auto"/>';
    }

    /// @dev None for Common and Rare, 4 for Epic, 8 for Legendary, 12 gold and
    ///      twinkling for Mythic.
    function _sparkleField(uint8 tier) private pure returns (string memory) {
        uint256 count;
        string memory colour = "#FFFFFF";
        if (tier == 2) count = 4;
        if (tier == 1) { count = 8; colour = "#FFF6C0"; }
        if (tier == 0) { count = 12; colour = "#FFD700"; }
        if (count == 0) return "";

        string memory out;
        for (uint256 i = 0; i < count; ++i) {
            uint256 packed = (SPARKLES >> (i * 12)) & 0xFFF;
            out = string(abi.encodePacked(out, _rect(packed & 0x3F, (packed >> 6) & 0x3F, colour)));
        }
        if (tier == 0) {
            return string(abi.encodePacked(
                '<g><animate attributeName="opacity" values="1;0.25;1" dur="1.8s" repeatCount="indefinite"/>',
                out,
                '</g>'
            ));
        }
        return out;
    }

    /// @dev One 10px cell of the 48x48 grid.
    function _rect(uint256 x, uint256 y, string memory color) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<rect x="', (x * 10).toString(), '" y="', (y * 10).toString(),
            '" width="10" height="10" fill="', color, '"/>'
        ));
    }

    /**
     * @dev Draws a front-facing chibi opossum as one cohesive rounded silhouette.
     *      Technique: paint the full black body shape first, then paint the
     *      body-color fill inset 1px on every side so a clean 1px outline is
     *      left automatically. Then layer the cream belly, white face mask,
     *      expression-driven eyes, pink nose, blush, pattern and accessory.
     *      Pointy pink-lined ears up top; a hairless tail curls off the body.
     */
    /**
     * @dev Composites one opossum in paint order. All sprite data lives in the
     *      PARTS contract; this function only decides the order and supplies
     *      the two per-token colours.
     */
    function _drawOpossum(uint256 seed) private view returns (string memory) {
        string memory eyeColor = PALETTE.eyeColor(seed);
        // forge-lint: disable-next-line(unsafe-typecast)
        string memory out = string(abi.encodePacked(
            PARTS.drawBase(PALETTE.bodyColor(seed)),
            PARTS.drawEyes(uint8((seed >> 8) % 10), eyeColor),
            PARTS.drawFace()
        ));
        return string(abi.encodePacked(
            out,
            // forge-lint: disable-next-line(unsafe-typecast)
            PARTS.drawPattern(uint8((seed >> 16) % 10), SHADE),
            // forge-lint: disable-next-line(unsafe-typecast)
            PARTS.drawAccessory(uint8((seed >> 24) % 15), eyeColor),
            PARTS.drawVolume()
        ));
    }
}
