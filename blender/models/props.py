"""Props along the path and in the landmarks (see src/server/Build/Props.luau). Each one is
the same size as the parts version the game builds without it, so nothing moves.
Blender +Y is the front (it's -Z in Roblox, where the game turns a prop's front).

  BerryBush     "Bush" (three leafy lumps) and "Berry"
  FallenLog     an 8-stud log lying along X: "Log", "Rings" (the light ends) and "Moss"
  LampPost      a 9-stud post with an arm to the front: "Post", "Iron" and "Lantern"
  FenceSection  one post with two rails running 3 studs to the front: "Post", "Rail_1", "Rail_2"
  Pumpkin       "Pumpkin" (lumpy, with ribs) and "Stem"
  Gravestone1-3 a slab with a stepped top, a cross and a pillar: "Stone", "Moss" and "Mound"
                (the earth in front)
  Reeds         "Reed" (stalks and long leaves) and "Cattail"
  LilyPad       "Pad", and a flower on it: "Flower" and "Middle"
"""

import math
import random

from lib import palette
from lib.geometry import Piece, blob, box, cap, place


def berry_bush(collection):
    rng = random.Random(201)
    bush = Piece("Bush", palette.BUSH)
    lumps = [((2.6, 2.4, 2.0), (0, 0, 1.0)), ((1.8, 1.8, 1.6), (1.2, -0.5, 0.8)), ((1.6, 1.6, 1.4), (-1.1, 0.4, 0.7))]
    for size, where in lumps:
        bush.add(box(size, bevel=0.32), place(where, turn_z=rng.uniform(-15, 15)))
        top = (size[0] * 0.6, size[1] * 0.6, size[2] * 0.45)
        bush.add(box(top, bevel=0.22), place((where[0], where[1], where[2] + size[2] / 2), turn_z=rng.uniform(20, 50)))
    bush.build(collection)
    berries = Piece("Berry", palette.BERRY)
    for _ in range(9):
        size, (x, y, z) = lumps[rng.randrange(len(lumps))]
        if rng.random() < 0.5:
            spot = (x + rng.uniform(-0.35, 0.35) * size[0], y + rng.uniform(-0.35, 0.35) * size[1], z + size[2] / 2 + 0.1)
        else:
            angle = rng.uniform(0, 2 * math.pi)
            spot = (x + math.cos(angle) * size[0] / 2, y + math.sin(angle) * size[1] / 2, z + rng.uniform(-0.2, 0.35) * size[2])
        berries.add(box((0.4, 0.4, 0.4), bevel=0.08), place(spot, turn_z=rng.uniform(0, 90)))
    berries.build(collection)


def fallen_log(collection):
    rng = random.Random(202)
    length, thick = 8.0, 1.8
    log = Piece("Log", palette.BARK)
    log.add(box((length, thick, thick), bevel=0.25), place((0, 0, thick / 2)))
    # Bark ridges along the top and the two sides.
    for side in range(3):
        for i in range(2):
            offset = (i - 0.5) * thick * 0.45 + rng.uniform(-0.08, 0.08)
            ridge = box((length * rng.uniform(0.7, 0.92), 0.36, 0.16), bevel=0.06)
            if side == 0:
                log.add(ridge, place((rng.uniform(-0.4, 0.4), offset, thick + 0.02)))
            else:
                y = (1 if side == 1 else -1) * (thick / 2 + 0.02)
                log.add(ridge, place((rng.uniform(-0.4, 0.4), y, thick / 2 + offset), tilt_x=90))
    # A broken-off branch.
    log.add(box((0.6, 0.6, 1.4), bevel=0.1, taper=0.7), place((1.6, 0.3, thick + 0.5), tilt_y=25, tilt_x=-15))
    log.build(collection)
    rings = Piece("Rings", palette.INNER_WOOD)
    for end in (-1, 1):
        rings.add(box((0.08, thick * 0.82, thick * 0.82), bevel=0.02), place((end * (length / 2 + 0.01), 0, thick / 2)))
    rings.build(collection)
    moss = Piece("Moss", palette.MOSS)
    moss.add(box((length * 0.4, thick * 0.75, 0.18), bevel=0.06, jitter=0.04, rng=rng), place((rng.uniform(-1.5, 0), 0, thick + 0.12)))
    moss.build(collection)


def lamp_post(collection):
    post = Piece("Post", palette.DARK_WOOD)
    post.add(box((0.6, 0.6, 9.0), bevel=0.08), place((0, 0, 4.5)))
    post.add(box((0.4, 2.2, 0.4), bevel=0.06), place((0, 0.9, 8.6)))
    post.add(box((0.25, 0.25, 1.5), bevel=0.04), place((0, 0.5, 7.95), tilt_x=-45))  # the brace under the arm
    post.add(box((0.8, 0.8, 0.5), bevel=0.1, taper=0.8), place((0, 0, 0.25)))  # a wider foot
    post.build(collection)
    iron = Piece("Iron", palette.IRON)
    iron.add(box((1.2, 1.2, 0.3), bevel=0.06, taper=0.55), place((0, 1.8, 8.1)))
    iron.add(box((1.0, 1.0, 0.12), bevel=0.03), place((0, 1.8, 6.8)))
    iron.add(box((0.12, 0.12, 0.35)), place((0, 1.8, 8.4)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            iron.add(box((0.1, 0.1, 1.15)), place((sx * 0.45, 1.8 + sy * 0.45, 7.4)))
    iron.build(collection)
    Piece("Lantern", palette.LAMP).add(box((0.8, 0.8, 1.0), bevel=0.06), place((0, 1.8, 7.4))).build(collection)


def fence_section(collection):
    post = Piece("Post", palette.WOOD)
    post.add(box((0.5, 0.5, 3.0), bevel=0.06), place((0, 0, 1.5)))
    post.add(box((0.5, 0.5, 0.35), taper=0.15), place((0, 0, 3.17), turn_z=45))
    post.build(collection)
    for i, z in enumerate((1.1, 2.2)):
        Piece(f"Rail_{i + 1}", palette.WOOD).add(box((0.25, 3.3, 0.4), bevel=0.05), place((0, 1.5, z))).build(collection)


def pumpkin(collection):
    rng = random.Random(205)
    body = Piece("Pumpkin", palette.PUMPKIN)
    body.add(box((1.7, 1.7, 1.6), bevel=0.4), place((0, 0, 0.85)))
    for i in range(4):
        angle = math.radians(45 + 90 * i)
        body.add(box((1.25, 1.25, 1.5), bevel=0.38), place((math.cos(angle) * 0.5, math.sin(angle) * 0.5, 0.8), turn_z=45 + 90 * i))
    body.build(collection)
    stem = Piece("Stem", palette.PUMPKIN_STEM)
    stem.add(box((0.35, 0.35, 0.65), bevel=0.05, taper=0.7), place((0, 0, 1.85), tilt_y=rng.uniform(8, 15)))
    stem.add(box((0.6, 0.35, 0.06)), place((0.3, 0.1, 1.68), turn_z=30, tilt_y=-20))  # a curly leaf
    stem.build(collection)


def _gravestone(collection, seed, top):
    """A grave: a stone base, `top` (a list of (size, z) boxes on it), some moss over the
    stone's flat tops, and a mound of earth in front."""
    rng = random.Random(seed)
    stone = Piece("Stone", palette.GRAVE_STONE)
    moss = Piece("Moss", palette.MOSS)
    base = box((2.6, 1.2, 0.4), bevel=0.08, jitter=0.03, rng=rng)
    stone.add(base, place((0, 0, 0.2)))
    for size, z in top:
        part = box(size, bevel=0.1, jitter=0.03, rng=rng)
        where = place((0, 0, z))
        if rng.random() < 0.5:
            moss.add(cap(part, min_up=0.8, lift=0.02, thickness=0.06), where)
        stone.add(part, where)
    stone.build(collection)
    moss.add(box((0.9, 0.5, 0.08), bevel=0.02), place((rng.uniform(-0.6, 0.6), -0.2, 0.42)))
    moss.build(collection)
    mound = Piece("Mound", palette.DIRT)
    mound.add(box((2.0, 3.6, 0.45), bevel=0.15, taper=0.75, jitter=0.05, rng=rng), place((0, 2.4, 0.2)))
    mound.build(collection)


def gravestone1(collection):
    """A slab with a stepped, rounded-looking top."""
    _gravestone(collection, 206, [((2.0, 0.6, 2.4), 1.6), ((1.6, 0.6, 0.5), 3.05), ((1.0, 0.6, 0.35), 3.45)])


def gravestone2(collection):
    """A cross."""
    _gravestone(collection, 207, [((0.6, 0.6, 3.6), 2.2), ((2.2, 0.6, 0.6), 3.0)])


def gravestone3(collection):
    """A short pillar with a cap and a point."""
    _gravestone(collection, 208, [((1.1, 1.1, 3.4), 2.1), ((1.4, 1.4, 0.4), 3.95), ((0.9, 0.9, 0.6), 4.45)])


def reeds(collection):
    rng = random.Random(209)
    reed = Piece("Reed", palette.REED)
    tails = Piece("Cattail", palette.CATTAIL)
    for i in range(6):
        height = rng.uniform(2.5, 4.0)
        x, y = rng.uniform(-1.2, 1.2), rng.uniform(-1.2, 1.2)
        tilt_x, tilt_y = rng.uniform(-7, 7), rng.uniform(-7, 7)
        reed.add(box((0.18, 0.18, height)), place((x, y, height / 2), tilt_x=tilt_x, tilt_y=tilt_y))
        if i % 2 == 1:
            tails.add(box((0.35, 0.35, 0.8), bevel=0.1), place((x, y, height - 0.5), tilt_x=tilt_x, tilt_y=tilt_y))
    # A few long, flat leaves bending out.
    for i in range(4):
        length = rng.uniform(1.8, 2.6)
        reed.add(box((0.3, 0.05, length), taper=0.2), place((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), length / 2 - 0.1), turn_z=i * 90 + rng.uniform(-20, 20), tilt_x=rng.uniform(15, 30)))
    reed.build(collection)
    tails.build(collection)


def lily_pad(collection):
    rng = random.Random(210)
    Piece("Pad", palette.LILY).add(blob(0.9, 0.9, 0.08, sides=11, jitter=0.08, rng=rng), place((0, 0, 0.04))).build(collection)
    flower = Piece("Flower", palette.LILY_FLOWER)
    for i in range(5):
        angle = i * 72
        a = math.radians(angle)
        flower.add(box((0.32, 0.18, 0.14), bevel=0.04), place((math.cos(a) * 0.17, math.sin(a) * 0.17, 0.2), turn_z=angle, tilt_y=-30))
    flower.build(collection)
    Piece("Middle", palette.YELLOW).add(box((0.2, 0.2, 0.18), bevel=0.04), place((0, 0, 0.3))).build(collection)
