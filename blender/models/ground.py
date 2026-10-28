"""Things that lie on the ground: patches, pebbles and the river's banks.

  Patch1-3   flat, irregular blobs (one object "Patch"). The game stretches them paper-thin
             and paints them, so a zone's floor isn't one flat colour.
  Pebbles    three small stones (one object "Pebble") along the path's edges.
  RiverBank  a 12-stud stretch of river bank: "Sand" rises from the grass to a low crest and
             slopes down into the water (its water side is +Y here, -Z in Roblox), and
             "Stone" is a row of small stones along the water's edge.
"""

import random

from lib import palette
from lib.geometry import Piece, blob, box, place, ridge


def patch1(collection):
    """A roundish patch."""
    Piece("Patch", palette.GRASS_LIGHT).add(blob(5.0, 4.4, 0.12, sides=12, jitter=0.14, rng=random.Random(81))).build(collection)


def patch2(collection):
    """A long patch."""
    Piece("Patch", palette.GRASS_LIGHT).add(blob(6.5, 3.2, 0.12, sides=13, jitter=0.12, rng=random.Random(82))).build(collection)


def patch3(collection):
    """A patch pinched in the middle, like two patches that ran together."""
    Piece("Patch", palette.GRASS_LIGHT).add(blob(6.0, 3.8, 0.12, sides=14, jitter=0.1, waist=0.45, rng=random.Random(83))).build(collection)


def pebbles(collection):
    """Three little stones."""
    rng = random.Random(71)
    piece = Piece("Pebble", palette.STONE)
    for size, x, y in [(0.9, 0, 0), (0.6, 0.75, 0.35), (0.45, -0.55, 0.45)]:
        piece.add(
            box((size, size * 0.85, size * 0.6), bevel=size * 0.22, jitter=size * 0.07, rng=rng),
            place((x, y, size * 0.27), turn_z=rng.uniform(0, 90)),
        )
    piece.build(collection)


def river_bank(collection):
    """A stretch of river bank, 12 studs long and about 4 deep."""
    rng = random.Random(61)
    # Across the bank (y, from the grass to the water) and up (z).
    profile = [(0.0, 0.0), (0.0, 0.08), (0.9, 0.55), (1.7, 0.72), (2.6, 0.48), (3.4, 0.16), (3.8, 0.0)]
    Piece("Sand", palette.SAND).add(ridge(12.0, profile, sections=4, wobble=0.25, rise_jitter=0.18, rng=rng)).build(collection)
    stones = Piece("Stone", palette.STONE)
    for i in range(7):
        size = rng.uniform(0.45, 0.8)
        x = -5.4 + i * 1.8 + rng.uniform(-0.4, 0.4)
        stones.add(
            box((size, size * 0.9, size * 0.7), bevel=size * 0.2, jitter=size * 0.08, rng=rng),
            place((x, 3.3 + rng.uniform(-0.2, 0.2), size * 0.22), turn_z=rng.uniform(0, 90)),
        )
    for _ in range(2):
        size = rng.uniform(0.5, 0.75)
        stones.add(
            box((size, size * 0.9, size * 0.7), bevel=size * 0.2, jitter=size * 0.08, rng=rng),
            place((rng.uniform(-4.5, 4.5), 1.6 + rng.uniform(-0.3, 0.3), 0.62), turn_z=rng.uniform(0, 90)),
        )
    stones.build(collection)
