"""Trees, and the bark block a chopped trunk's notch is built from.

Every tree is built at Scale 1 in studs, standing on z = 0, with these objects (the game
looks for them by name, see src/server/Build/Assets.luau and Blocky.tree):
  Trunk        a square block with bark ridges. Its width must match Config.Models.Trees
  Root_N       wedges at the foot of the trunk (they stay behind with the stump)
  Branch_N     bark-coloured branches (optional)
  Leaves       the biggest crown block (a mimic's "Sway" tell moves it)
  LeafBlock_N  the other crown blocks (the game welds them to Leaves)

Shapes: Oak, Oak2, Pine, Pine2, Birch, Birch2 (Pale Pines), Willow1-2 (Fog Hollow, with long
strands hanging from the crown) and DeadOak1-2 (Graveyard Grove, bare forked branches and a
few dark leaves).
"""

import math
import random

from lib import palette
from lib.geometry import Piece, bark, box, leaf_clump, place, wedge
from mathutils import Vector


def roots(collection, trunk_width, length, height, count=4):
    """Root wedges sticking out of the middle of each side of the trunk."""
    for i in range(count):
        root = Piece(f"Root_{i + 1}", palette.ROOT)
        reach = trunk_width / 2 + length
        root.add(wedge((trunk_width * 0.45, reach, height), bevel=0.12), place((0, reach / 2, 0), orbit_z=i * 360 / count))
        root.build(collection)


def limb(piece, start, length, thickness, azimuth, tilt, taper=0.65):
    """A branch from `start`, `length` long, leaning `tilt` degrees from straight up towards
    `azimuth` (degrees around Z), thinner at its tip. Returns where its tip is."""
    a, t = math.radians(azimuth), math.radians(tilt)
    direction = Vector((math.sin(t) * math.cos(a), math.sin(t) * math.sin(a), math.cos(t)))
    centre = Vector(start) + direction * length / 2
    piece.add(box((thickness, thickness, length), bevel=thickness * 0.15, taper=taper), place(centre, turn_z=azimuth, tilt_y=tilt))
    return Vector(start) + direction * length


def leaf_blocks(collection, color, blocks, rng):
    """Crown blocks LeafBlock_1, _2...: (size, (x, y, z), turn) each."""
    for i, (size, where, turn) in enumerate(blocks):
        leaf_clump(Piece(f"LeafBlock_{i + 1}", color), size, where, turn=turn, bumps=1, rng=rng).build(collection)


def oak(collection):
    """The everyday tree: a thick trunk and a big, leafy, lumpy crown."""
    rng = random.Random(11)
    width, height = 3.0, 14.0
    bark(Piece("Trunk", palette.BARK), width, height, ridges=3, rng=rng).build(collection)
    roots(collection, width, 1.6, 1.6)
    branch = Piece("Branch_1", palette.BARK)
    branch.add(box((0.9, 0.9, 4.2), bevel=0.15), place((1.7, 0.2, 11.6), turn_z=10, tilt_y=38))
    branch.build(collection)
    leaf_clump(Piece("Leaves", palette.OAK_LEAF), 10, (0, 0, 15.6), turn=20, bumps=1, rng=rng).build(collection)
    blocks = [
        (7.4, (4.4, 1.2, 15.0), 38),
        (7.0, (-4.2, -1.8, 16.2), 8),
        (6.4, (0.9, -4.4, 17.6), 52),
        (6.0, (-1.6, 3.8, 19.6), 25),
        (4.6, (1.2, 0.4, 21.6), 40),
    ]
    for i, (size, where, turn) in enumerate(blocks):
        leaf_clump(Piece(f"LeafBlock_{i + 1}", palette.OAK_LEAF), size, where, turn=turn, bumps=1, rng=rng).build(collection)


def pine(collection):
    """Pale Pines' namesake: a slim trunk under five stacked, pointed tiers, each turned
    45 degrees from the one below, so the outline looks like layers of branches."""
    rng = random.Random(23)
    width, height = 2.2, 8.0
    bark(Piece("Trunk", palette.BARK), width, height, ridges=2, rng=rng).build(collection)
    roots(collection, width, 1.2, 1.2)
    tiers = [
        # width, bottom, height, turn
        (10.0, 4.0, 3.8, 0),
        (8.4, 7.0, 3.6, 45),
        (6.8, 9.9, 3.3, 0),
        (5.2, 12.5, 3.1, 45),
        (3.6, 14.9, 2.8, 0),
    ]
    for i, (w, bottom, h, turn) in enumerate(tiers):
        piece = Piece("Leaves" if i == 0 else f"LeafBlock_{i}", palette.PINE_LEAF)
        piece.add(box((w, w, h), bevel=0.28, taper=0.6), place((0, 0, bottom + h / 2), turn_z=turn + rng.uniform(-4, 4)))
        piece.build(collection)
    top = Piece(f"LeafBlock_{len(tiers)}", palette.PINE_LEAF)
    top.add(box((1.9, 1.9, 2.6), bevel=0.2, taper=0.3), place((0, 0, 17.3 + 1.3), turn_z=45))
    top.build(collection)


def birch(collection):
    """A tall, thin white tree with a small crown. The game draws the dark bark marks."""
    rng = random.Random(37)
    width, height = 2.4, 16.8
    bark(Piece("Trunk", palette.BIRCH), width, height, ridges=2, rng=rng).build(collection)
    roots(collection, width, 1.2, 1.3)
    leaf_clump(Piece("Leaves", palette.BIRCH_LEAF), 7.5, (0, 0, 17.9), turn=15, bumps=1, rng=rng).build(collection)
    blocks = [
        (5.4, (3.0, 1.0, 18.8), 40),
        (5.0, (-2.8, -1.3, 19.8), 5),
        (4.0, (0.4, 0.6, 22.0), 30),
    ]
    for i, (size, where, turn) in enumerate(blocks):
        leaf_clump(Piece(f"LeafBlock_{i + 1}", palette.BIRCH_LEAF), size, where, turn=turn, bumps=1, rng=rng).build(collection)


def bark_block(collection):
    """One bark block. The game stretches copies of it into the pieces of a chopped trunk
    (above, below and behind the notch), so a cut trunk keeps its bark."""
    bark(Piece("BarkBlock", palette.BARK), 3.0, 3.0, ridges=3, rng=random.Random(3)).build(collection)


def oak2(collection):
    """A broad, round oak: a shorter trunk with two branches and a wide crown."""
    rng = random.Random(12)
    width, height = 3.0, 12.5
    bark(Piece("Trunk", palette.BARK), width, height, ridges=3, rng=rng).build(collection)
    roots(collection, width, 1.8, 1.7)
    branches = Piece("Branch_1", palette.BARK)
    limb(branches, (0.6, 0, 10.0), 5.0, 1.0, 25, 52)
    limb(branches, (-0.6, 0, 10.4), 4.6, 0.9, 205, 48)
    branches.build(collection)
    leaf_clump(Piece("Leaves", palette.OAK_LEAF), 11, (0, 0, 15.6), turn=12, bumps=1, rng=rng).build(collection)
    leaf_blocks(
        collection,
        palette.OAK_LEAF,
        [
            (8.0, (5.8, 1.0, 14.6), 30),
            (7.6, (-5.6, -0.8, 14.8), 10),
            (7.0, (0.5, 5.4, 15.4), 55),
            (7.0, (-0.8, -5.2, 15.0), 20),
            (6.0, (2.6, -2.0, 19.4), 40),
            (5.6, (-2.4, 2.2, 19.8), 15),
        ],
        rng,
    )


def pine2(collection):
    """A tall, slim spruce: six narrow tiers, each a little off-centre."""
    rng = random.Random(24)
    width, height = 2.2, 7.0
    bark(Piece("Trunk", palette.BARK), width, height, ridges=2, rng=rng).build(collection)
    roots(collection, width, 1.2, 1.2)
    tiers = [
        # width, bottom, height, turn
        (8.6, 3.5, 3.4, 0),
        (7.6, 6.2, 3.3, 45),
        (6.6, 8.8, 3.2, 0),
        (5.6, 11.3, 3.0, 45),
        (4.6, 13.6, 2.8, 0),
        (3.4, 15.7, 2.6, 45),
    ]
    for i, (w, bottom, h, turn) in enumerate(tiers):
        piece = Piece("Leaves" if i == 0 else f"LeafBlock_{i}", palette.PINE_LEAF)
        shift = (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), bottom + h / 2)
        piece.add(box((w, w, h), bevel=0.26, taper=0.62), place(shift, turn_z=turn + rng.uniform(-6, 6)))
        piece.build(collection)
    top = Piece(f"LeafBlock_{len(tiers)}", palette.PINE_LEAF)
    top.add(box((1.6, 1.6, 2.6), bevel=0.18, taper=0.3), place((0, 0, 18.3 + 1.3), turn_z=45))
    top.build(collection)


def birch2(collection):
    """A birch with a split crown: two clumps of leaves, one higher than the other."""
    rng = random.Random(38)
    width, height = 2.4, 15.0
    bark(Piece("Trunk", palette.BIRCH), width, height, ridges=2, rng=rng).build(collection)
    roots(collection, width, 1.2, 1.3)
    branch = Piece("Branch_1", palette.BIRCH)
    limb(branch, (-0.4, 0, 12.0), 3.4, 0.6, 165, 42)
    branch.build(collection)
    leaf_clump(Piece("Leaves", palette.BIRCH_LEAF), 6.6, (0.8, 0, 16.4), turn=20, bumps=1, rng=rng).build(collection)
    leaf_blocks(
        collection,
        palette.BIRCH_LEAF,
        [
            (5.6, (-2.8, 0.8, 16.0), 25),
            (4.8, (2.8, -1.2, 18.6), 50),
            (4.6, (-0.6, -0.4, 20.6), 10),
            (3.6, (1.2, 1.4, 22.6), 35),
        ],
        rng,
    )


def _willow(collection, seed, height, lobes, strands, strand_length):
    """A willow: a short, thick trunk, thick branches into a wide, domed crown (`lobes`:
    (width, depth, x, y, z) each, the first is Leaves), and a curtain of long strands hanging
    from its edge, flaring out a little at the bottom. The strands and crown are split into
    six LeafBlocks around the tree, so the game can shade each side a little differently."""
    rng = random.Random(seed)
    width = 3.2
    bark(Piece("Trunk", palette.BARK), width, height, ridges=3, rng=rng).build(collection)
    roots(collection, width, 2.0, 1.8)
    branches = Piece("Branch_1", palette.BARK)
    for azimuth in (0, 120, 240):
        limb(branches, (0, 0, height - 1), 4.8, 1.1, azimuth + rng.uniform(-15, 15), 42)
    branches.build(collection)

    def dome(piece, w, d, x, y, z):
        """Three stacked, bevelled layers, each smaller than the one below: a rounded crown."""
        turn = rng.uniform(-10, 10)
        piece.add(box((w, d, 3.0), bevel=0.9), place((x, y, z), turn_z=turn))
        piece.add(box((w * 0.78, d * 0.78, 2.8), bevel=0.8), place((x, y, z + 2.2), turn_z=turn + rng.uniform(8, 18)))
        piece.add(box((w * 0.46, d * 0.46, 2.4), bevel=0.6), place((x, y, z + 4.1), turn_z=turn + rng.uniform(25, 45)))

    crown_z = lobes[0][4]
    leaves = Piece("Leaves", palette.WILLOW_LEAF)
    dome(leaves, *lobes[0])
    leaves.build(collection)

    sectors = 6
    blocks = [Piece(f"LeafBlock_{i + 1}", palette.WILLOW_LEAF) for i in range(sectors)]
    for lobe in lobes[1:]:
        dome(blocks[rng.randrange(sectors)], *lobe)
    # The curtain: two rings of strands around the edge of the whole crown (an oval around
    # all the lobes), the inner ring a little shorter.
    left = min(lx - lw / 2 for lw, _, lx, _, _ in lobes)
    right = max(lx + lw / 2 for lw, _, lx, _, _ in lobes)
    rx, ry = (right - left) / 2 - 0.5, max(ld for _, ld, *_ in lobes) / 2 - 0.4
    cx = (left + right) / 2
    for ring, (inset, shorter) in enumerate([(1.0, 1.0), (0.78, 0.75)]):
        count = strands if ring == 0 else strands * 2 // 3
        for i in range(count):
            angle = (i + rng.uniform(-0.3, 0.3) + ring * 0.5) / count * 2 * math.pi
            length = rng.uniform(*strand_length) * shorter
            top = (cx + math.cos(angle) * rx * inset, math.sin(angle) * ry * inset, crown_z + 0.4)
            sector = int((angle % (2 * math.pi)) / (2 * math.pi) * sectors) % sectors
            # Pointing down (tilt 180), leaning a few degrees outwards, thinner at the bottom.
            limb(blocks[sector], top, length, rng.uniform(0.85, 1.25), math.degrees(angle), 180 - rng.uniform(4, 12), taper=0.5)
    for block in blocks:
        block.build(collection)


def willow1(collection):
    _willow(collection, 51, 9.5, [(14.0, 11.0, 0, 0, 11.6)], 30, (5.5, 8.5))


def willow2(collection):
    _willow(collection, 52, 11.0, [(12.0, 9.0, 2.2, 0, 13.2), (10.0, 8.0, -4.6, 0.8, 12.4)], 32, (6.5, 10.0))


def _dead_oak(collection, seed, height, arms, leaf_spots):
    """A dead oak: a dark trunk, long gnarly roots, and bare branches that fork (`arms`:
    (azimuth, tilt, length, thickness, forks) each, forks being (azimuth, tilt, length)),
    with little twigs at the fork tips and a few small clumps of dark leaves at some tips
    (`leaf_spots`: (which tip, size), biggest first; the first is Leaves)."""
    rng = random.Random(seed)
    width = 3.0
    bark(Piece("Trunk", palette.DEAD_BARK), width, height, ridges=3, rng=rng).build(collection)
    roots(collection, width, 2.6, 2.1)
    tips = []
    for i, (azimuth, tilt, length, thick, forks) in enumerate(arms):
        branch = Piece(f"Branch_{i + 1}", palette.DEAD_BARK)
        start = (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), height - 0.8)
        tip = limb(branch, start, length, thick, azimuth, tilt)
        tips.append(tip)
        for fork_azimuth, fork_tilt, fork_length in forks:
            fork_tip = limb(branch, tip - Vector((0, 0, 0.2)), fork_length, thick * 0.6, fork_azimuth, fork_tilt, taper=0.5)
            tips.append(fork_tip)
            # A crooked little twig off the end.
            limb(branch, fork_tip, rng.uniform(1.4, 2.2), thick * 0.3, fork_azimuth + rng.uniform(-70, 70), rng.uniform(25, 65), taper=0.5)
        branch.build(collection)
    # A broken-off stub low on the trunk.
    stub = Piece(f"Branch_{len(arms) + 1}", palette.DEAD_BARK)
    limb(stub, (width * 0.3, 0, height * 0.55), 2.4, 0.8, rng.uniform(0, 360), 68, taper=0.8)
    stub.build(collection)
    for i, (tip_index, size) in enumerate(leaf_spots):
        name = "Leaves" if i == 0 else f"LeafBlock_{i}"
        leaf_clump(Piece(name, palette.DEAD_LEAF), size, tuple(tips[tip_index]), turn=rng.uniform(0, 90), bumps=1, rng=rng).build(collection)


def dead_oak1(collection):
    # Tips, in order: arm 1 (0) and its forks (1, 2), arm 2 (3) and fork (4), arm 3 (5) and
    # forks (6, 7), arm 4 (8) and fork (9).
    _dead_oak(
        collection,
        61,
        10.5,
        [
            (15, 38, 6.5, 1.4, [(55, 58, 3.8), (-20, 20, 3.2)]),
            (95, 52, 5.0, 1.1, [(130, 68, 3.0)]),
            (170, 42, 6.0, 1.3, [(210, 62, 3.4), (150, 22, 2.8)]),
            (265, 30, 6.8, 1.2, [(300, 55, 3.2)]),
        ],
        [(2, 3.0), (6, 2.5), (9, 2.3)],
    )


def dead_oak2(collection):
    # Tips: arm 1 (0) and forks (1, 2), arm 2 (3) and forks (4, 5), arm 3 (6) and fork (7),
    # arm 4 (8) and forks (9, 10).
    _dead_oak(
        collection,
        62,
        11.0,
        [
            (35, 34, 7.0, 1.4, [(85, 60, 3.8), (10, 18, 3.4)]),
            (115, 48, 5.6, 1.2, [(160, 66, 3.2), (95, 25, 2.6)]),
            (200, 40, 6.2, 1.3, [(240, 60, 3.0)]),
            (-40, 44, 6.4, 1.2, [(-85, 64, 3.2), (-15, 22, 2.8)]),
        ],
        [(1, 2.8), (7, 2.5), (10, 2.2)],
    )
