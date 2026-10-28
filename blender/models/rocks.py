"""Rocks. Objects: "Rock" (the stone, with a smaller stone leaning on it) and "Moss" (a
green cap on top; the game removes it from rocks that shouldn't be mossy)."""

import random

from lib import palette
from lib.geometry import Piece, box, place


def rock1(collection):
    """A chunky rock with a smaller one leaning on its side."""
    rng = random.Random(41)
    stone = Piece("Rock", palette.STONE)
    stone.add(box((4.0, 3.4, 2.8), bevel=0.7, jitter=0.22, rng=rng), place((0, 0, 1.4), turn_z=8))
    stone.add(box((2.0, 1.8, 1.5), bevel=0.45, jitter=0.14, rng=rng), place((2.5, 0.9, 0.75), turn_z=35, tilt_y=-12))
    stone.build(collection)
    moss = Piece("Moss", palette.MOSS)
    moss.add(box((2.7, 2.1, 0.32), bevel=0.12, jitter=0.04, rng=rng), place((-0.15, 0.05, 2.86), turn_z=8))
    moss.build(collection)


def rock2(collection):
    """A wide, flat boulder with two smaller stones beside it."""
    rng = random.Random(53)
    stone = Piece("Rock", palette.STONE)
    stone.add(box((4.6, 3.8, 2.2), bevel=0.8, jitter=0.26, rng=rng), place((0, 0, 1.1), turn_z=-12))
    stone.add(box((2.2, 2.0, 1.6), bevel=0.5, jitter=0.15, rng=rng), place((-2.5, -1.1, 0.8), turn_z=22, tilt_x=8))
    stone.add(box((1.1, 1.0, 0.8), bevel=0.25, jitter=0.08, rng=rng), place((2.6, 1.7, 0.4), turn_z=50))
    stone.build(collection)
    moss = Piece("Moss", palette.MOSS)
    moss.add(box((3.2, 2.6, 0.32), bevel=0.12, jitter=0.05, rng=rng), place((0.1, -0.1, 2.25), turn_z=-12))
    moss.build(collection)
