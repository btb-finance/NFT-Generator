#!/usr/bin/env python3
"""
Generates src/OposParts.sol from the sprite tables below.

WHY THIS EXISTS
---------------
Hand-written Solidity draw calls cost roughly 600 bytes of bytecode *per rect*
(each one inlines its own string literals). At ~130 rects across the expression,
pattern and accessory tables that came to 23 KB — within 1.3 KB of the EIP-170
limit, with no room left to make the art nicer.

Encoded as data, one rect is 5 bytes: x, y, w, h, colour index. A single
decoder loop walks the blob and emits the same SVG. Same pixels, ~100x less
bytecode per rect, so there is finally headroom to draw properly.

THIS FILE IS THE SOURCE OF TRUTH for those sprites. Edit the tables here and
re-run; do not hand-edit the generated hex in the .sol file.

    python3 scripts/gen_art_data.py

Rect format: (x, y, w, h, colour). Colour is a literal string from the palette,
or the sentinel "IRIS" (the token's eye colour) / "SHADE" (the body-derived
translucent shade). A 1x1 rect renders byte-identically to the old _pixel()
helper, so the encoding reproduces the previous output exactly.
"""

IRIS = "IRIS"
SHADE = "SHADE"
BODY = "BODY"

BLACK = "#000"
WHITE = "#FFFFFF"
PUPIL = "#1A1A1A"


def eye(x, y):
    """The 2x2 round eye: sparkle, two iris cells, pupil."""
    return [
        (x, y, 1, 1, WHITE),
        (x + 1, y, 1, 1, IRIS),
        (x, y + 1, 1, 1, IRIS),
        (x + 1, y + 1, 1, 1, PUPIL),
    ]


# ── Expressions (10) ────────────────────────────────────────────────────────
EXPRESSIONS = [
    # 0 Happy — upward closed arcs
    [(8, 9, 2, 1, BLACK), (9, 8, 1, 1, BLACK), (14, 9, 2, 1, BLACK), (14, 8, 1, 1, BLACK)],
    # 1 Sleepy — flat half-closed lines
    [(8, 9, 2, 1, BLACK), (14, 9, 2, 1, BLACK)],
    # 2 Winking — left closed, right open
    [(8, 9, 2, 1, BLACK)] + eye(14, 8),
    # 3 Surprised — wide round iris eyes
    eye(8, 8) + eye(14, 8),
    # 4 Grumpy — iris eyes under dark angled brows
    [(8, 9, 2, 1, IRIS), (14, 9, 2, 1, IRIS), (8, 8, 1, 1, BLACK), (15, 8, 1, 1, BLACK),
     (9, 9, 1, 1, PUPIL), (14, 9, 1, 1, PUPIL)],
    # 5 Loving — heart eyes
    [(8, 8, 1, 1, "#FF4D8D"), (9, 8, 1, 1, "#FF4D8D"), (8, 9, 1, 1, "#B0144E"),
     (14, 8, 1, 1, "#FF4D8D"), (15, 8, 1, 1, "#FF4D8D"), (15, 9, 1, 1, "#B0144E")],
    # 6 Excited
    eye(8, 8) + eye(14, 8),
    # 7 Shy — soft half-closed lines with a dark outer anchor
    [(8, 9, 1, 1, "#2A2A2A"), (9, 9, 1, 1, IRIS), (14, 9, 1, 1, IRIS), (15, 9, 1, 1, "#2A2A2A")],
    # 8 Curious — one wide eye, one narrow
    eye(8, 8) + [(14, 9, 1, 1, PUPIL), (15, 9, 1, 1, IRIS)],
    # 9 Normal
    eye(8, 8) + eye(14, 8),
]

# ── Patterns (10) ───────────────────────────────────────────────────────────
CALICO_A = "rgba(232,145,60,0.50)"
CALICO_B = "rgba(0,0,0,0.32)"
CALICO_C = "rgba(255,255,255,0.45)"

PATTERNS = [
    [],  # 0 None
    # 1 Striped
    [(7, 14, 1, 5, SHADE), (10, 14, 1, 5, SHADE), (13, 14, 1, 5, SHADE), (16, 14, 1, 5, SHADE)],
    # 2 Spotted
    [(8, 15, 1, 1, SHADE), (15, 16, 1, 1, SHADE), (11, 17, 1, 1, SHADE), (13, 14, 1, 1, SHADE)],
    # 3 Tuxedo
    [(11, 14, 2, 5, WHITE)],
    # 4 Patches
    [(7, 14, 3, 2, SHADE), (14, 16, 3, 2, SHADE)],
    # 5 Tiger Stripes
    [(8, 15, 3, 1, BLACK), (13, 17, 3, 1, BLACK)],
    # 6 Gradient
    [(6, 18, 12, 1, SHADE)],
    # 7 Calico — translucent so it tints the fur underneath
    [(6, 14, 1, 1, CALICO_A), (7, 14, 1, 1, CALICO_A), (7, 13, 1, 1, CALICO_A),
     (6, 15, 1, 1, CALICO_A), (15, 14, 1, 1, CALICO_B), (16, 14, 1, 1, CALICO_B),
     (16, 15, 1, 1, CALICO_B), (7, 17, 1, 1, CALICO_C), (8, 17, 1, 1, CALICO_C)],
    # 8 Galaxy Swirl
    [(8, 14, 1, 1, "#9B30FF"), (11, 15, 1, 1, WHITE), (14, 14, 1, 1, "#4B0082"),
     (16, 17, 1, 1, "#9B30FF"), (9, 18, 1, 1, WHITE), (13, 16, 1, 1, "#4B0082")],
    # 9 Flames
    [(7, 19, 1, 1, "#FF6347"), (9, 18, 1, 2, "#FF4500"), (11, 19, 2, 1, "#FFA500"),
     (14, 18, 1, 2, "#FF4500"), (16, 19, 1, 1, "#FF6347")],
]

# ── Accessories (15) ────────────────────────────────────────────────────────
GOLD = "#FFD700"
SILVER = "#C0C0C0"
CAPE_RED = "#B22222"

ACCESSORIES = [
    [],  # 0 None
    # 1 Crown
    [(9, 2, 6, 2, GOLD), (10, 1, 1, 1, GOLD), (12, 1, 1, 1, GOLD), (14, 1, 1, 1, GOLD)],
    # 2 Top Hat
    [(9, 0, 6, 2, BLACK), (8, 2, 8, 1, BLACK)],
    # 3 Bow Tie
    [(10, 13, 1, 1, "#FF0000"), (13, 13, 1, 1, "#FF0000"),
     (11, 13, 1, 1, "#FF0000"), (12, 13, 1, 1, "#FF0000")],
    # 4 Sunglasses
    [(8, 7, 3, 2, BLACK), (13, 7, 3, 2, BLACK), (11, 7, 2, 1, BLACK)],
    # 5 Bandana — headband, knot, trailing tails
    [(8, 5, 8, 1, "#E74C3C"), (7, 5, 1, 1, "#E74C3C"),
     (6, 6, 1, 1, "#E74C3C"), (6, 7, 1, 1, "#C0392B")],
    # 6 Astronaut Helmet — open frame so the face stays visible
    [(8, 3, 8, 1, SILVER), (7, 4, 1, 1, SILVER), (16, 4, 1, 1, SILVER),
     (6, 5, 1, 1, SILVER), (17, 5, 1, 1, SILVER), (5, 6, 1, 5, SILVER),
     (18, 6, 1, 5, SILVER), (8, 4, 1, 1, WHITE), (7, 5, 1, 1, WHITE)],
    # 7 Pirate Eye Patch
    [(13, 7, 3, 2, BLACK), (7, 6, 10, 1, BLACK)],
    # 8 Golden Crown
    [(8, 1, 8, 3, GOLD), (9, 0, 1, 1, GOLD), (11, 0, 1, 1, GOLD),
     (13, 0, 1, 1, GOLD), (15, 0, 1, 1, GOLD)],
    # 9 Wizard Hat
    [(11, 0, 2, 3, "#4B0082"), (10, 3, 4, 1, "#4B0082"), (12, 2, 1, 1, GOLD)],
    # 10 Flower Crown
    [(8, 3, 1, 1, "#FF69B4"), (10, 3, 1, 1, GOLD), (12, 3, 1, 1, "#FF1493"),
     (14, 3, 1, 1, "#FF69B4"), (16, 3, 1, 1, GOLD)],
    # 11 Monocle
    [(13, 7, 2, 2, SILVER), (14, 8, 1, 1, IRIS)],
    # 12 Cape — collar on the shoulders, fabric pooling at the corners
    [(7, 13, 3, 1, CAPE_RED), (14, 13, 3, 1, CAPE_RED), (5, 16, 1, 1, CAPE_RED),
     (5, 17, 1, 1, CAPE_RED), (4, 18, 2, 1, CAPE_RED), (3, 19, 3, 1, "#8B1A1A"),
     (18, 16, 1, 1, CAPE_RED), (18, 17, 1, 1, CAPE_RED), (18, 18, 2, 1, CAPE_RED),
     (18, 19, 3, 1, "#8B1A1A")],
    # 13 Halo — open ring floating above the head
    [(10, 0, 4, 1, GOLD), (9, 1, 1, 1, "#FFE680"), (14, 1, 1, 1, "#FFE680"),
     (10, 2, 1, 1, GOLD), (13, 2, 1, 1, GOLD)],
    # 14 Headphones
    [(7, 3, 10, 1, BLACK), (6, 3, 1, 4, BLACK), (17, 3, 1, 4, BLACK),
     (6, 4, 1, 1, "#FF1493"), (17, 4, 1, 1, "#FF1493")],
]

# ── Body, face and lighting (3 sprites in one table) ────────────────────────
PINK = "#FFC0CB"
PINK_SOFT = "#FFB6C1"
CREAM = "#FFF6E9"
LIT = "rgba(255,255,255,0.22)"
DIM = "rgba(0,0,0,0.20)"

# The whole character below the trait overlays. Paint order matters: the tail
# goes down first so the body silhouette tucks over its base, then the black
# silhouette, then the fur fill inset 1px inside it (which is what leaves the
# 1px outline showing), then ears, belly and the white face mask.
BASE = (
    # tail — black underside first, then the fur/pink fill on top
    [(18, 18, 1, 1, BLACK), (19, 18, 1, 1, BLACK), (20, 17, 1, 1, BLACK),
     (21, 17, 1, 1, BLACK), (22, 16, 1, 1, BLACK), (22, 15, 1, 1, BLACK),
     (22, 14, 1, 1, BLACK), (21, 13, 1, 1, BLACK), (20, 13, 1, 1, BLACK),
     (18, 17, 1, 1, BODY), (19, 17, 1, 1, BODY), (20, 16, 1, 1, BODY),
     (21, 16, 1, 1, PINK), (21, 15, 1, 1, PINK), (21, 14, 1, 1, PINK),
     (20, 14, 1, 1, PINK_SOFT)]
    # ears — rounded and dark (pointy triangles read as a cat)
    + [(7, 2, 2, 1, BLACK), (6, 3, 3, 2, BLACK), (15, 2, 2, 1, BLACK), (15, 3, 3, 2, BLACK)]
    # head outline, rows 4-12
    + [(9, 4, 6, 1, BLACK), (8, 5, 8, 1, BLACK), (7, 6, 10, 2, BLACK),
       (6, 8, 12, 3, BLACK), (7, 11, 10, 1, BLACK), (8, 12, 8, 1, BLACK)]
    # body outline, rows 13-20
    + [(7, 13, 10, 1, BLACK), (6, 14, 12, 1, BLACK), (5, 15, 14, 3, BLACK),
       (6, 18, 12, 1, BLACK), (7, 19, 10, 1, BLACK), (9, 20, 6, 1, BLACK)]
    # fur fill, inset 1px
    + [(9, 5, 6, 1, BODY), (8, 6, 8, 2, BODY), (7, 8, 10, 3, BODY),
       (8, 11, 8, 1, BODY), (9, 12, 6, 1, BODY)]
    + [(8, 13, 8, 1, BODY), (7, 14, 10, 1, BODY), (6, 15, 12, 2, BODY),
       (7, 17, 10, 1, BODY), (8, 18, 8, 1, BODY), (9, 19, 6, 1, BODY)]
    # pink inner ears
    + [(7, 3, 1, 1, PINK), (16, 3, 1, 1, PINK)]
    # soft cream belly
    + [(9, 15, 6, 2, CREAM), (10, 17, 4, 1, CREAM)]
    # white face mask — the iconic opossum look
    + [(9, 7, 6, 1, WHITE), (8, 8, 8, 2, WHITE), (9, 10, 6, 1, WHITE), (10, 11, 4, 1, WHITE)]
)

# Snout, nose and blush, then the feet. Drawn after the eyes.
FACE = [
    (10, 12, 1, 1, WHITE), (13, 12, 1, 1, WHITE),
    (11, 12, 1, 1, "#FF6FA5"), (12, 12, 1, 1, "#FF6FA5"),
    (8, 10, 1, 1, PINK_SOFT), (15, 10, 1, 1, PINK_SOFT),
    (9, 20, 1, 1, PINK), (10, 20, 1, 1, PINK), (13, 20, 1, 1, PINK), (14, 20, 1, 1, PINK),
]

# Rim light upper-left, shadow lower-right. Translucent, so one set of cells
# works for all 30 body colours. Kept clear of the face mask.
VOLUME = [
    (9, 5, 2, 1, LIT), (8, 6, 1, 1, LIT), (7, 8, 1, 2, LIT),
    (7, 14, 1, 1, LIT), (6, 15, 1, 2, LIT),
    (14, 5, 1, 1, DIM), (15, 6, 1, 1, DIM), (16, 8, 1, 3, DIM), (15, 11, 1, 1, DIM),
    (16, 14, 1, 1, DIM), (17, 15, 1, 2, DIM), (16, 17, 1, 1, DIM), (9, 19, 6, 1, DIM),
]

MISC = [BASE, FACE, VOLUME]

# ── 48x48 face (authored directly in render space, NOT doubled) ─────────────
# The 24x24 grid gave each eye a 2x2 blob and left no cells at all for a mouth,
# which is why the opossum had none. At 48x48 the face mask spans cols 16-31 /
# rows 14-25, so each eye gets a 4x4 socket and the snout tip has two spare
# rows for a nose and a mouth.

NOSE = "#FF6FA5"
MOUTH = "#1A1A1A"

L, R, TOP = 16, 28, 16   # left eye x, right eye x, eye y — both eyes are 4x4


def eye48(x, y, iris):
    """A 4x4 socket: dark rim, iris fill, white sparkle, dark pupil."""
    return [
        (x + 1, y, 2, 1, BLACK),          # rim: top
        (x, y + 1, 1, 2, BLACK),          # rim: left
        (x + 3, y + 1, 1, 2, BLACK),      # rim: right
        (x + 1, y + 3, 2, 1, BLACK),      # rim: bottom
        (x + 1, y + 1, 2, 2, iris),       # iris
        (x + 2, y + 2, 1, 1, PUPIL),      # pupil
        (x + 1, y + 1, 1, 1, WHITE),      # sparkle
    ]


def arc48(x, y):
    """A closed, upward-curving eye (the ∩ of a happy squint)."""
    return [(x, y + 1, 1, 1, BLACK), (x + 1, y, 2, 1, BLACK), (x + 3, y + 1, 1, 1, BLACK)]


def lash48(x, y, colour):
    """A half-closed horizontal line."""
    return [(x, y, 4, 1, colour)]


def heart48(x, y):
    """A 4x4 pixel heart, bright on top with a darker point."""
    return [
        (x, y, 1, 1, "#FF4D8D"), (x + 2, y, 1, 1, "#FF4D8D"),
        (x, y + 1, 4, 1, "#FF4D8D"),
        (x + 1, y + 2, 2, 1, "#B0144E"),
    ]


EXPRESSIONS48 = [
    # 0 Happy — upward closed arcs
    arc48(L, TOP + 1) + arc48(R, TOP + 1),
    # 1 Sleepy — flat half-closed lines
    lash48(L, TOP + 2, BLACK) + lash48(R, TOP + 2, BLACK),
    # 2 Winking — left closed, right open
    arc48(L, TOP + 1) + eye48(R, TOP, IRIS),
    # 3 Surprised — wide open, extra sparkle
    eye48(L, TOP, IRIS) + eye48(R, TOP, IRIS)
    + [(L + 2, TOP + 1, 1, 1, WHITE), (R + 2, TOP + 1, 1, 1, WHITE)],
    # 4 Grumpy — open eyes under heavy angled brows
    eye48(L, TOP, IRIS) + eye48(R, TOP, IRIS)
    + [(L, TOP - 1, 2, 1, BLACK), (L + 2, TOP, 2, 1, BLACK),
       (R + 2, TOP - 1, 2, 1, BLACK), (R, TOP, 2, 1, BLACK)],
    # 5 Loving — heart eyes
    heart48(L, TOP + 1) + heart48(R, TOP + 1),
    # 6 Excited — open eyes with a big double sparkle
    eye48(L, TOP, IRIS) + eye48(R, TOP, IRIS)
    + [(L + 2, TOP + 1, 1, 1, WHITE), (R + 1, TOP + 2, 1, 1, WHITE)],
    # 7 Shy — half-closed iris lines, dark at the outer corners
    lash48(L, TOP + 2, IRIS) + lash48(R, TOP + 2, IRIS)
    + [(L, TOP + 2, 1, 1, "#2A2A2A"), (R + 3, TOP + 2, 1, 1, "#2A2A2A")],
    # 8 Curious — one wide open eye, one narrowed
    eye48(L, TOP, IRIS) + lash48(R, TOP + 2, IRIS)
    + [(R, TOP + 2, 1, 1, PUPIL)],
    # 9 Normal
    eye48(L, TOP, IRIS) + eye48(R, TOP, IRIS),
]

# Snout tip, nose, mouth, blush and feet — the parts that sit under/around the
# eyes. Rows 24-25 are the last two rows of the head, now split between a
# tapered nose and the mouth beneath it.
FACE48 = [
    # white snout tip across the full width of the muzzle
    (20, 24, 8, 2, WHITE),
    # nose: wide on top, tapering to a point
    (22, 22, 4, 1, NOSE), (23, 23, 2, 1, NOSE),
    # mouth: a small "w" smile under the nose
    (23, 24, 2, 1, MOUTH),
    (22, 25, 1, 1, MOUTH), (25, 25, 1, 1, MOUTH),
    # blush
    (16, 20, 2, 2, PINK_SOFT), (30, 20, 2, 2, PINK_SOFT),
    # feet
    (18, 40, 2, 2, PINK), (20, 40, 2, 2, PINK), (26, 40, 2, 2, PINK), (28, 40, 2, 2, PINK),
]

# ── Encoding ────────────────────────────────────────────────────────────────

# The art below is authored on a 24x24 grid. It is doubled to a 48x48 grid at
# encode time so there are four times as many cells to draw detail into, while
# the canvas stays 480x480 (cells shrink from 20px to 10px). Doubling is exact:
# one 20px cell becomes four 10px cells of the same colour, so scaling alone
# changes no rendered pixel.
CELL = 10


def s2(sprite):
    """24x24 authoring space -> 48x48 render space."""
    return [(x * 2, y * 2, w * 2, h * 2, c) for x, y, w, h, c in sprite]


BODY_INDEX = 253
IRIS_INDEX = 254
SHADE_INDEX = 255


def build_palette(tables):
    """Stable palette ordering: first appearance across all sprite tables."""
    palette = []
    for table in tables:
        for sprite in table:
            for *_, colour in sprite:
                if colour not in (IRIS, SHADE, BODY) and colour not in palette:
                    palette.append(colour)
    if len(palette) > BODY_INDEX:
        raise SystemExit(f"palette too large for a 1-byte index: {len(palette)}")
    return palette


def colour_index(colour, palette):
    if colour == IRIS:
        return IRIS_INDEX
    if colour == SHADE:
        return SHADE_INDEX
    if colour == BODY:
        return BODY_INDEX
    return palette.index(colour)


def encode_table(table, palette):
    """Returns (data bytes, offsets bytes). Offsets are n+1 big-endian uint16."""
    data = bytearray()
    offsets = [0]
    for sprite in table:
        for x, y, w, h, colour in sprite:
            for v in (x, y, w, h):
                if not 0 <= v <= 255:
                    raise SystemExit(f"value {v} does not fit in a byte")
            data += bytes([x, y, w, h, colour_index(colour, palette)])
        offsets.append(len(data))
    offs = bytearray()
    for o in offsets:
        if o > 0xFFFF:
            raise SystemExit("offset overflows uint16")
        offs += o.to_bytes(2, "big")
    return bytes(data), bytes(offs)


def encode_palette(palette):
    """Colour strings packed end to end, with n+1 big-endian uint16 offsets."""
    data = bytearray()
    offsets = [0]
    for colour in palette:
        data += colour.encode("ascii")
        offsets.append(len(data))
    offs = bytearray()
    for o in offsets:
        offs += o.to_bytes(2, "big")
    return bytes(data), bytes(offs)


def hex_literal(b):
    return f'hex"{b.hex()}"'


def main():
    # expressions and the face are authored at 48x48 already; the rest is doubled
    expressions = EXPRESSIONS48
    patterns = [s2(sp) for sp in PATTERNS]
    accessories = [s2(sp) for sp in ACCESSORIES]
    misc = [s2(BASE), FACE48, s2(VOLUME)]

    palette = build_palette([expressions, patterns, accessories, misc])
    pal_data, pal_offs = encode_palette(palette)
    exp_data, exp_offs = encode_table(expressions, palette)
    pat_data, pat_offs = encode_table(patterns, palette)
    acc_data, acc_offs = encode_table(accessories, palette)
    misc_data, misc_offs = encode_table(misc, palette)

    total = sum(len(x) for x in
                (pal_data, pal_offs, exp_data, exp_offs, pat_data, pat_offs,
                 acc_data, acc_offs, misc_data, misc_offs))
    rects = sum(len(s) for t in (expressions, patterns, accessories, misc) for s in t)

    sol = f'''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {{Strings}} from "@openzeppelin/contracts/utils/Strings.sol";

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
 *      limit, with no room to improve the art. The same {rects} rects now
 *      occupy {total} bytes of data.
 *
 *      Colour indices {IRIS_INDEX} and {SHADE_INDEX} are sentinels for the two
 *      per-token colours: the eye colour and the body-derived shade.
 */
contract OposParts {{
    using Strings for uint256;

    /// @dev Colour strings packed end to end, sliced via PAL_OFFS.
    bytes private constant PAL = {hex_literal(pal_data)};
    bytes private constant PAL_OFFS = {hex_literal(pal_offs)};

    bytes private constant EXP = {hex_literal(exp_data)};
    bytes private constant EXP_OFFS = {hex_literal(exp_offs)};

    bytes private constant PAT = {hex_literal(pat_data)};
    bytes private constant PAT_OFFS = {hex_literal(pat_offs)};

    bytes private constant ACC = {hex_literal(acc_data)};
    bytes private constant ACC_OFFS = {hex_literal(acc_offs)};

    /// @dev 0 = body/tail/ears/belly/mask, 1 = snout and feet, 2 = lighting.
    bytes private constant MISC = {hex_literal(misc_data)};
    bytes private constant MISC_OFFS = {hex_literal(misc_offs)};

    uint8 private constant BODY = {BODY_INDEX};
    uint8 private constant IRIS = {IRIS_INDEX};
    uint8 private constant SHADE = {SHADE_INDEX};

    // ── public draw API (unchanged) ──

    /// @notice Silhouette, fur, ears, belly and face mask, in the token's body colour.
    function drawBase(string memory bodyColor) external pure returns (string memory) {{
        return _render(MISC, MISC_OFFS, 0, "", "", bodyColor);
    }}

    /// @notice Snout, nose, blush and feet. Painted after the eyes.
    function drawFace() external pure returns (string memory) {{
        return _render(MISC, MISC_OFFS, 1, "", "", "");
    }}

    /// @notice Rim light and shadow, painted last to unify the whole figure.
    function drawVolume() external pure returns (string memory) {{
        return _render(MISC, MISC_OFFS, 2, "", "", "");
    }}

    function drawEyes(uint8 expression, string memory eyeColor) external pure returns (string memory) {{
        return _render(EXP, EXP_OFFS, expression, eyeColor, "", "");
    }}

    function drawPattern(uint8 pattern, string memory shade) external pure returns (string memory) {{
        return _render(PAT, PAT_OFFS, pattern, "", shade, "");
    }}

    function drawAccessory(uint8 accessory, string memory eyeColor) external pure returns (string memory) {{
        return _render(ACC, ACC_OFFS, accessory, eyeColor, "", "");
    }}

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
    ) private pure returns (string memory out) {{
        uint256 slot = uint256(index) * 2;
        if (slot + 3 >= offs.length) return "";
        uint256 cursor = _u16(offs, slot);
        uint256 end = _u16(offs, slot + 2);
        for (; cursor < end; cursor += 5) {{
            out = string(abi.encodePacked(out, _rect(
                uint8(data[cursor]),
                uint8(data[cursor + 1]),
                uint8(data[cursor + 2]),
                uint8(data[cursor + 3]),
                _color(uint8(data[cursor + 4]), iris, shade, body)
            )));
        }}
    }}

    function _color(uint8 index, string memory iris, string memory shade, string memory body)
        private
        pure
        returns (string memory)
    {{
        if (index == IRIS) return iris;
        if (index == SHADE) return shade;
        if (index == BODY) return body;
        bytes memory offs = PAL_OFFS;
        uint256 slot = uint256(index) * 2;
        return _slice(PAL, _u16(offs, slot), _u16(offs, slot + 2));
    }}

    function _u16(bytes memory b, uint256 i) private pure returns (uint256) {{
        return (uint256(uint8(b[i])) << 8) | uint256(uint8(b[i + 1]));
    }}

    function _slice(bytes memory b, uint256 start, uint256 end) private pure returns (string memory) {{
        bytes memory out = new bytes(end - start);
        for (uint256 i; i < out.length; ++i) out[i] = b[start + i];
        return string(out);
    }}

    /// @dev A w-by-h block at (x, y) on the 48x48 grid, {CELL}px cells.
    function _rect(uint256 x, uint256 y, uint256 w, uint256 h, string memory color)
        private
        pure
        returns (string memory)
    {{
        return string(abi.encodePacked(
            '<rect x="', (x * {CELL}).toString(), '" y="', (y * {CELL}).toString(),
            '" width="', (w * {CELL}).toString(), '" height="', (h * {CELL}).toString(),
            '" fill="', color, '"/>'
        ));
    }}
}}
'''

    with open("src/OposParts.sol", "w") as f:
        f.write(sol)

    print(f"palette: {len(palette)} colours ({len(pal_data)} B + {len(pal_offs)} B offsets)")
    print(f"sprites: {rects} rects across "
          f"{len(EXPRESSIONS)} expressions, {len(PATTERNS)} patterns, {len(ACCESSORIES)} accessories")
    print(f"total embedded data: {total} bytes")
    print("wrote src/OposParts.sol")


if __name__ == "__main__":
    main()
