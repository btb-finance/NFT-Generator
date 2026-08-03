// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @notice Minimal standard-alphabet base64 decoder, test-only. Lets metadata
///         tests assert on the real decoded JSON that a marketplace would see,
///         instead of pattern-matching the opaque base64 blob.
library Base64Decode {
    /// @dev Decodes `data`. Expects the standard alphabet with `=` padding —
    ///      exactly what OpenZeppelin's Base64.encode produces.
    function decode(string memory data) internal pure returns (string memory) {
        bytes memory input = bytes(data);
        if (input.length == 0) return "";
        require(input.length % 4 == 0, "Base64Decode: bad length");

        uint256 padding;
        if (input[input.length - 1] == "=") padding++;
        if (input[input.length - 2] == "=") padding++;

        bytes memory out = new bytes((input.length / 4) * 3 - padding);
        uint256 o;
        for (uint256 i = 0; i < input.length; i += 4) {
            uint256 chunk = (_val(input[i]) << 18) | (_val(input[i + 1]) << 12)
                | (_val(input[i + 2]) << 6) | _val(input[i + 3]);
            if (o < out.length) out[o++] = bytes1(uint8(chunk >> 16));
            if (o < out.length) out[o++] = bytes1(uint8((chunk >> 8) & 0xFF));
            if (o < out.length) out[o++] = bytes1(uint8(chunk & 0xFF));
        }
        return string(out);
    }

    function _val(bytes1 c) private pure returns (uint256) {
        uint8 x = uint8(c);
        if (x >= 65 && x <= 90) return x - 65;   // A-Z
        if (x >= 97 && x <= 122) return x - 71;  // a-z
        if (x >= 48 && x <= 57) return x + 4;    // 0-9
        if (c == "+") return 62;
        if (c == "/") return 63;
        if (c == "=") return 0;                  // padding
        revert("Base64Decode: bad char");
    }

    /// @dev True if `haystack` contains `needle`.
    function contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > h.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; ++i) {
            bool ok = true;
            for (uint256 j = 0; j < n.length; ++j) {
                if (h[i + j] != n[j]) { ok = false; break; }
            }
            if (ok) return true;
        }
        return false;
    }

    /// @dev Strips a known prefix, reverting if it isn't there.
    function stripPrefix(string memory s, string memory prefix) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        bytes memory p = bytes(prefix);
        require(b.length >= p.length, "Base64Decode: too short");
        for (uint256 i = 0; i < p.length; ++i) require(b[i] == p[i], "Base64Decode: prefix mismatch");
        bytes memory out = new bytes(b.length - p.length);
        for (uint256 i = 0; i < out.length; ++i) out[i] = b[i + p.length];
        return string(out);
    }
}
