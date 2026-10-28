"""Little things scattered over the ground (see src/server/Build/Details.luau).

  GrassTuft   a tuft of grass blades: "Grass"
  Flowers     three little flowers: "Stem" and "Bloom" (the game picks the colour)
  Fern        fronds fanning out from the middle: "Frond"
  Mushrooms   three mushrooms: "Stem", "Cap" and "Dot" (white spots, gone on glowing ones)
  DeadLeaves  a scatter of flat dead leaves: "Leaf"
  Bones       a skull and two bones: "Bone"
"""

import math
import random

from lib import palette
from lib.geometry import Piece, box, place


def grass_tuft(collection):
    rng = random.Random(301)
    grass = Piece("Grass", palette.GRASS_TUFT)
    for i in range(8):
        height = rng.uniform(0.9, 1.6)
        angle = i * 45 + rng.uniform(-15, 15)
        a = math.radians(angle)
        r = rng.uniform(0.05, 0.35)
        grass.add(box((0.2, 0.12, height), taper=0.15), place((math.cos(a) * r, math.sin(a) * r, height / 2 - 0.05), turn_z=angle + 90, tilt_x=rng.uniform(10, 30)))
    grass.build(collection)


def flowers(collection):
    rng = random.Random(302)
    stems = Piece("Stem", palette.GRASS_TUFT)
    blooms = Piece("Bloom", palette.LILY_FLOWER)
    for x, y in [(0, 0), (0.55, 0.3), (-0.45, 0.4)]:
        height = rng.uniform(0.8, 1.3)
        stems.add(box((0.12, 0.12, height)), place((x, y, height / 2)))
        stems.add(box((0.35, 0.12, 0.05)), place((x + 0.15, y, height * 0.4), tilt_y=-25))  # a leaf
        turn = rng.uniform(0, 90)
        blooms.add(box((0.26, 0.26, 0.22), bevel=0.04), place((x, y, height + 0.08), turn_z=turn))
        for i in range(4):
            a = math.radians(turn + i * 90)
            blooms.add(box((0.26, 0.16, 0.1), bevel=0.03), place((x + math.cos(a) * 0.2, y + math.sin(a) * 0.2, height + 0.05), turn_z=turn + i * 90))
    stems.build(collection)
    blooms.build(collection)


def fern(collection):
    rng = random.Random(303)
    fronds = Piece("Frond", palette.FERN)

    def segment(start, length, width, azimuth, tilt, taper):
        """A flat, pointed piece of frond from `start`, leaning `tilt` degrees out from straight
        up towards `azimuth`. Returns where it ends."""
        a, t = math.radians(azimuth), math.radians(tilt)
        direction = (math.sin(t) * math.cos(a), math.sin(t) * math.sin(a), math.cos(t))
        centre = tuple(s + d * length / 2 for s, d in zip(start, direction))
        fronds.add(box((width, 0.06, length), taper=taper), place(centre, turn_z=azimuth - 90, tilt_x=-tilt))
        return tuple(s + d * length for s, d in zip(start, direction))

    count = 8
    for i in range(count):
        azimuth = i * 360 / count + rng.uniform(-12, 12)
        # Each frond rises steeply, then bends over: two pieces, the outer one droops.
        bend = segment((0, 0, 0.05), rng.uniform(0.9, 1.2), 0.62, azimuth, rng.uniform(28, 40), 0.85)
        segment(bend, rng.uniform(0.9, 1.3), 0.52, azimuth, rng.uniform(70, 88), 0.2)
    fronds.build(collection)


def mushrooms(collection):
    rng = random.Random(304)
    stems = Piece("Stem", palette.CREAM)
    caps = Piece("Cap", palette.MUSHROOM_RED)
    dots = Piece("Dot", palette.CREAM)
    for i in range(3):
        scale = rng.uniform(0.7, 1.2)
        angle = i * 2.1 + rng.uniform(0, 0.6)
        x, y = math.cos(angle) * 0.6, math.sin(angle) * 0.6
        stem = 0.7 * scale
        stems.add(box((0.35 * scale, 0.35 * scale, stem), bevel=0.04), place((x, y, stem / 2)))
        top = stem + 0.2 * scale
        caps.add(box((1.0 * scale, 1.0 * scale, 0.45 * scale), bevel=0.12 * scale, taper=0.75), place((x, y, top)))
        for dx, dy in [(0.25, 0.2), (-0.2, -0.25)]:
            dots.add(box((0.22 * scale, 0.22 * scale, 0.05)), place((x + dx * scale, y + dy * scale, top + 0.23 * scale)))
    stems.build(collection)
    caps.build(collection)
    dots.build(collection)


def dead_leaves(collection):
    rng = random.Random(305)
    leaves = Piece("Leaf", palette.DEAD_LEAF)
    for _ in range(12):
        r, a = rng.uniform(0, 1.3), rng.uniform(0, 2 * math.pi)
        leaves.add(
            box((rng.uniform(0.45, 0.65), rng.uniform(0.28, 0.38), 0.05), bevel=0.015),
            place((math.cos(a) * r, math.sin(a) * r, 0.03 + rng.uniform(0, 0.05)), turn_z=rng.uniform(0, 180), tilt_x=rng.uniform(-8, 8)),
        )
    leaves.build(collection)


def bones(collection):
    rng = random.Random(306)
    bone = Piece("Bone", palette.BONE)
    bone.add(box((0.6, 0.7, 0.55), bevel=0.14), place((0, 0, 0.3), turn_z=20))  # the skull
    bone.add(box((0.45, 0.25, 0.16), bevel=0.04), place((0.12, 0.38, 0.1), turn_z=20))  # its jaw
    for x, y, turn in [(0.9, -0.3, 70), (-0.7, 0.5, -30)]:
        bone.add(box((1.2, 0.16, 0.16)), place((x, y, 0.08), turn_z=turn))
        a = math.radians(turn)
        for end in (-1, 1):
            bone.add(box((0.28, 0.28, 0.22), bevel=0.05), place((x + end * math.cos(a) * 0.6, y + end * math.sin(a) * 0.6, 0.11), turn_z=turn + rng.uniform(-10, 10)))
    bone.build(collection)
