"""Trees, and the bark block a chopped trunk's notch is built from.

Every tree is built at Scale 1 in studs, standing on z = 0, with these objects (the game
looks for them by name, see src/server/Build/Assets.luau and Blocky.tree):
  Trunk        a square block with bark ridges. Its width must match Config.Models.Trees
  Root_N       wedges at the foot of the trunk (they stay behind with the stump)
  Branch_N     bark-coloured branches (optional)
  Leaves       the biggest crown block (a mimic's "Sway" tell moves it)
  LeafBlock_N  the other crown blocks (the game welds them to Leaves)
"""

import math
import random

from lib import palette
from lib.geometry import Piece, bark, box, leaf_clump, place, wedge


def roots(collection, trunk_width, length, height, count=4):
    """Root wedges sticking out of the middle of each side of the trunk."""
    for i in range(count):
        root = Piece(f"Root_{i + 1}", palette.ROOT)
        reach = trunk_width / 2 + length
        root.add(wedge((trunk_width * 0.45, reach, height), bevel=0.12), place((0, reach / 2, 0), turn_z=i * 360 / count))
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
    leaf_clump(Piece("Leaves", palette.OAK_LEAF), 10, (0, 0, 15.6), turn=20, bumps=4, rng=rng).build(collection)
    blocks = [
        (7.0, (4.3, 1.4, 15.2), 35),
        (6.6, (-4.1, -1.9, 16.4), 10),
        (6.0, (0.8, -4.3, 18.0), 52),
        (5.4, (-1.4, 3.6, 20.2), 25),
    ]
    for i, (size, where, turn) in enumerate(blocks):
        leaf_clump(Piece(f"LeafBlock_{i + 1}", palette.OAK_LEAF), size, where, turn=turn, bumps=3, rng=rng).build(collection)


def pine(collection):
    """Pale Pines' namesake: a slim trunk under stacked, tapering tiers, each turned 45
    degrees from the one below, with little drooping tufts under their corners."""
    rng = random.Random(23)
    width, height = 2.2, 9.0
    bark(Piece("Trunk", palette.BARK), width, height, ridges=2, rng=rng).build(collection)
    roots(collection, width, 1.2, 1.2)
    tiers = [
        # width, bottom, height, turn
        (11.0, 4.5, 4.0, 0),
        (8.6, 8.0, 3.8, 45),
        (6.2, 11.3, 3.5, 0),
        (3.8, 14.4, 3.0, 45),
    ]
    for i, (w, bottom, h, turn) in enumerate(tiers):
        piece = Piece("Leaves" if i == 0 else f"LeafBlock_{i}", palette.PINE_LEAF)
        piece.add(box((w, w, h), bevel=0.3, taper=0.7), place((0, 0, bottom + h / 2), turn_z=turn))
        tuft = w * 0.2
        for corner in range(4):
            angle = turn + 45 + corner * 90
            reach = w * 0.42
            x, y = math.cos(math.radians(angle)) * reach, math.sin(math.radians(angle)) * reach
            piece.add(box((tuft, tuft, h * 0.42), bevel=tuft * 0.18, taper=1.15), place((x, y, bottom + h * 0.12), turn_z=angle + rng.uniform(-10, 10)))
        piece.build(collection)
    top = Piece(f"LeafBlock_{len(tiers)}", palette.PINE_LEAF)
    top.add(box((1.8, 1.8, 2.2), bevel=0.2, taper=0.35), place((0, 0, 17.4 + 1.1), turn_z=0))
    top.build(collection)


def birch(collection):
    """A tall, thin white tree with a small crown. The game draws the dark bark marks."""
    rng = random.Random(37)
    width, height = 2.4, 16.8
    bark(Piece("Trunk", palette.BIRCH), width, height, ridges=2, rng=rng).build(collection)
    roots(collection, width, 1.2, 1.3)
    leaf_clump(Piece("Leaves", palette.BIRCH_LEAF), 7.5, (0, 0, 17.9), turn=15, bumps=4, rng=rng).build(collection)
    blocks = [
        (5.2, (2.9, 1.0, 19.4), 40),
        (4.6, (-2.6, -1.2, 20.5), 5),
        (3.6, (0.4, 0.6, 22.4), 30),
    ]
    for i, (size, where, turn) in enumerate(blocks):
        leaf_clump(Piece(f"LeafBlock_{i + 1}", palette.BIRCH_LEAF), size, where, turn=turn, bumps=2, rng=rng).build(collection)


def bark_block(collection):
    """One bark block. The game stretches copies of it into the pieces of a chopped trunk
    (above, below and behind the notch), so a cut trunk keeps its bark."""
    bark(Piece("BarkBlock", palette.BARK), 3.0, 3.0, ridges=3, rng=random.Random(3)).build(collection)
