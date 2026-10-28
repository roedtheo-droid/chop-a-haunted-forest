"""Trees, and the bark block a chopped trunk's notch is built from.

Every tree is built at Scale 1 in studs, standing on z = 0, with these objects (the game
looks for them by name, see src/server/Build/Assets.luau and Blocky.tree):
  Trunk        a square block with bark ridges. Its width must match Config.Models.Trees
  Root_N       wedges at the foot of the trunk (they stay behind with the stump)
  Branch_N     bark-coloured branches (optional)
  Leaves       the biggest crown block (a mimic's "Sway" tell moves it)
  LeafBlock_N  the other crown blocks (the game welds them to Leaves)
"""

import random

from lib import palette
from lib.geometry import Piece, bark, box, leaf_clump, place, wedge


def roots(collection, trunk_width, length, height, count=4):
    """Root wedges sticking out of the middle of each side of the trunk."""
    for i in range(count):
        root = Piece(f"Root_{i + 1}", palette.ROOT)
        reach = trunk_width / 2 + length
        root.add(wedge((trunk_width * 0.45, reach, height), bevel=0.12), place((0, reach / 2, 0), orbit_z=i * 360 / count))
        root.build(collection)


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
