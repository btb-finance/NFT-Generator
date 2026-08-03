// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title OposParts
 * @dev The trait overlays — expressions, fur patterns and accessories.
 *
 *      GENERATED FILE. Edit scripts/gen_art_data.py and re-run it; do not
 *      hand-edit the hex blobs below.
 *
 *      Sprites are stored as data, not code. Each rect is 5 bytes
 *      (x, y, w, h, colour index) and one decoder loop emits the SVG. Writing
 *      these as literal Solidity draw calls cost ~600 bytes of bytecode per
 *      rect and pushed this contract to 23KB — 1.3KB short of the EIP-170
 *      limit, with no room to improve the art. The same 276 rects now
 *      occupy 1795 bytes of data.
 *
 *      Colour indices 254 and 255 are sentinels for the two
 *      per-token colours: the eye colour and the body-derived shade.
 */
contract OposParts {
    using Strings for uint256;

    /// @dev Colour strings packed end to end, sliced via PAL_OFFS.
    bytes private constant PAL = hex"23303030233141314131412346464646464623464634443844234230313434452332413241324172676261283233322c3134352c36302c302e3530297267626128302c302c302c302e33322972676261283235352c3235352c3235352c302e3435292339423330464623344230303832234646363334372346463435303023464641353030234646443730302346463030303023453734433343234330333932422343304330433023464636394234234646313439332342323232323223384231413141234646453638302346464330434223464642364331234646463645392346463646413572676261283235352c3235352c3235352c302e3232297267626128302c302c302c302e323029";
    bytes private constant PAL_OFFS = hex"00000004000b0012001900200027003c004c0062006900700077007e0085008c0093009a00a100a800af00b600bd00c400cb00d200d900e000e700fd010d";

    bytes private constant EXP = hex"1012010100111102010013120101001c120101001d110201001f1201010010120401001c120401001012010100111102010013120101001d100201001c110102001f110102001d130201001d110202fe1e120101011d11010102111002010010110102001311010200111302010011110202fe121201010111110101021d100201001c110102001f110102001d130201001d110202fe1e120101011d1101010212110101021e11010102111002010010110102001311010200111302010011110202fe121201010111110101021d100201001c110102001f110102001d130201001d110202fe1e120101011d11010102100f02010012100201001e0f0201001c1002010010110101031211010103101204010311130201041c110101031e110101031c120401031d13020104111002010010110102001311010200111302010011110202fe121201010111110101021d100201001c110102001f110102001d130201001d110202fe1e120101011d1101010212110101021d1201010210120401fe1c120401fe10120101051f12010105111002010010110102001311010200111302010011110202fe121201010111110101021c120401fe1c12010101111002010010110102001311010200111302010011110202fe121201010111110101021d100201001c110102001f110102001d130201001d110202fe1e120101011d11010102";
    bytes private constant EXP_OFFS = hex"0000001e0028005a00aa0104012c017c019001bd0203";

    bytes private constant PAT = hex"0e1c020aff141c020aff1a1c020aff201c020aff101e0202ff1e200202ff16220202ff1a1c0202ff161c040a020e1c0604ff1c200604ff101e0602001a220602000c241802ff0c1c0202060e1c0202060e1a0202060c1e0202061e1c020207201c020207201e0202070e220202081022020208101c020209161e0202021c1c02020a202202020912240202021a2002020a0e2602020b122402040c162604020d1c2402040c202602020b";
    bytes private constant PAT_OFFS = hex"0000000000140028002d0037004100460073009100aa";

    bytes private constant ACC = hex"12040c040e140202020e180202020e1c0202020e12000c04001004100200141a02020f1a1a02020f161a02020f181a02020f100e0604001a0e060400160e040200100a1002100e0a0202100c0c0202100c0e02021110061002120e0802021220080202120c0a020212220a0202120a0c020a12240c020a1210080202020e0a0202021a0e0604000e0c140200100210060e120002020e160002020e1a0002020e1e0002020e160004060a140608020a180402020e1006020213140602020e18060202141c06020213200602020e1a0e0404121c100202fe0e1a0602151c1a0602150a200202150a22020215082404021506260602162420020215242202021524240402152426060216140008020e12020202171c02020217140402020e1a0402020e0e061402000c0602080022060208000c080202142208020214";
    bytes private constant ACC_OFFS = hex"000000000014001e0032004100550082008c00a500b400cd00d701090122013b";

    /// @dev 0 = body/tail/ears/belly/mask, 1 = snout and feet, 2 = lighting.
    bytes private constant MISC = hex"2424020200262402020028220202002a220202002c200202002c1e0202002c1c0202002a1a020200281a02020024220202fd26220202fd28200202fd2a200202182a1e0202182a1c020218281c0202190e040402000c060604001e040402001e0606040012080c0200100a1002000e0c1404000c101806000e1614020010181002000e1a1402000c1c1802000a1e1c06000c241802000e2614020012280c0200120a0c02fd100c1004fd0e101406fd10161002fd12180c02fd101a1002fd0e1c1402fd0c1e1804fd0e221402fd10241002fd12260c02fd0e060202182006020218121e0c041a142208021a120e0c0202101010040212140c020214160802021418080202161604011b171702011b17180201011619010101191901010110140202191e14020219122802021814280202181a280202181c28020218120a04021c100c02021c0e1002041c0e1c02021c0c1e02041c1c0a02021d1e0c02021d201002061d1e1602021d201c02021d221e02041d202202021d12260c021d";
    bytes private constant MISC_OFFS = hex"000000ff013b017c";

    uint8 private constant BODY = 253;
    uint8 private constant IRIS = 254;
    uint8 private constant SHADE = 255;

    // ── public draw API (unchanged) ──

    /// @notice Silhouette, fur, ears, belly and face mask, in the token's body colour.
    function drawBase(string memory bodyColor) external pure returns (string memory) {
        return _render(MISC, MISC_OFFS, 0, "", "", bodyColor);
    }

    /// @notice Snout, nose, blush and feet. Painted after the eyes.
    function drawFace() external pure returns (string memory) {
        return _render(MISC, MISC_OFFS, 1, "", "", "");
    }

    /// @notice Rim light and shadow, painted last to unify the whole figure.
    function drawVolume() external pure returns (string memory) {
        return _render(MISC, MISC_OFFS, 2, "", "", "");
    }

    function drawEyes(uint8 expression, string memory eyeColor) external pure returns (string memory) {
        return _render(EXP, EXP_OFFS, expression, eyeColor, "", "");
    }

    function drawPattern(uint8 pattern, string memory shade) external pure returns (string memory) {
        return _render(PAT, PAT_OFFS, pattern, "", shade, "");
    }

    function drawAccessory(uint8 accessory, string memory eyeColor) external pure returns (string memory) {
        return _render(ACC, ACC_OFFS, accessory, eyeColor, "", "");
    }

    // ── decoder ──

    /// @dev Walks sprite `index` in `data` and emits one <rect> per record.
    ///      Out-of-range indices yield an empty string rather than reverting,
    ///      matching the old `return "";` fallthrough.
    function _render(
        bytes memory data,
        bytes memory offs,
        uint8 index,
        string memory iris,
        string memory shade,
        string memory body
    ) private pure returns (string memory out) {
        uint256 slot = uint256(index) * 2;
        if (slot + 3 >= offs.length) return "";
        uint256 cursor = _u16(offs, slot);
        uint256 end = _u16(offs, slot + 2);
        for (; cursor < end; cursor += 5) {
            out = string(abi.encodePacked(out, _rect(
                uint8(data[cursor]),
                uint8(data[cursor + 1]),
                uint8(data[cursor + 2]),
                uint8(data[cursor + 3]),
                _color(uint8(data[cursor + 4]), iris, shade, body)
            )));
        }
    }

    function _color(uint8 index, string memory iris, string memory shade, string memory body)
        private
        pure
        returns (string memory)
    {
        if (index == IRIS) return iris;
        if (index == SHADE) return shade;
        if (index == BODY) return body;
        bytes memory offs = PAL_OFFS;
        uint256 slot = uint256(index) * 2;
        return _slice(PAL, _u16(offs, slot), _u16(offs, slot + 2));
    }

    function _u16(bytes memory b, uint256 i) private pure returns (uint256) {
        return (uint256(uint8(b[i])) << 8) | uint256(uint8(b[i + 1]));
    }

    function _slice(bytes memory b, uint256 start, uint256 end) private pure returns (string memory) {
        bytes memory out = new bytes(end - start);
        for (uint256 i; i < out.length; ++i) out[i] = b[start + i];
        return string(out);
    }

    /// @dev A w-by-h block at (x, y) on the 48x48 grid, 10px cells.
    function _rect(uint256 x, uint256 y, uint256 w, uint256 h, string memory color)
        private
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(
            '<rect x="', (x * 10).toString(), '" y="', (y * 10).toString(),
            '" width="', (w * 10).toString(), '" height="', (h * 10).toString(),
            '" fill="', color, '"/>'
        ));
    }
}
