"""The forest's edges (see src/server/Build/Edges.luau): hedges along the outside, and the
rocky ridge, crumbling stone wall and gatehouses between zones.

  Hedge1-3        a 12-stud hedge (along X, about 4 deep): "Hedge" leaf clumps with an uneven
                  top, and "Twig" dark sticks (the game keeps them only in Graveyard Grove)
  RidgeRock1-2    big rocks for the ridge: "Rock" and "Moss" on top
  StoneWall1-2    8 studs of crumbling wall: "Stone" blocks (with rubble) and "Moss"
  LogGatehouse    two log towers with roofs and beams around the 16-stud gate: "Log", "Roof",
                  "Sign" (the game writes on it), "Lamp" and "Iron" (the lamps' arms)
  StoneGatehouse  two stone pillars with an iron arch: "Stone", "Iron", "Sign" and "Lamp"
Both gatehouses are exactly 30 studs wide (X), with the gate's opening in the middle.
"""

import math
import random

from lib import palette
from lib.geometry import Piece, box, cap, leaf_clump, place

GATE = 16.0  # the gate's width (Config.Gates.Width)
TOWER = 7.0  # each tower or pillar is this wide, so a gatehouse is 16 + 2 * 7 = 30 wide
TOWER_X = GATE / 2 + TOWER / 2


def _hedge(collection, seed, tops):
    """A 12-stud hedge whose clumps reach the heights in `tops` along its length."""
    rng = random.Random(seed)
    leaves = Piece("Hedge", palette.HEDGE)
    leaves.add(box((11.6, 3.2, 3.2), bevel=0.4), place((0, 0, 1.6)))
    # A lower row of clumps all along it, so there are no holes under the tall ones...
    x = -5.2
    while x < 5.6:
        size = rng.uniform(3.4, 4.2)
        leaf_clump(leaves, size, (x, rng.uniform(-0.35, 0.35), 3.2 + rng.uniform(-0.3, 0.4)), turn=rng.uniform(-20, 20), bumps=1, rng=rng)
        x += size * rng.uniform(0.7, 0.85)
    # ...and taller clumps on top, each reaching a different height.
    for i, top in enumerate(tops):
        size = rng.uniform(3.2, 4.4)
        x = -4.4 + i * 8.8 / max(len(tops) - 1, 1) + rng.uniform(-0.5, 0.5)
        leaf_clump(leaves, size, (x, rng.uniform(-0.4, 0.4), top - size / 2), turn=rng.uniform(-25, 25), bumps=1, rng=rng)
    leaves.build(collection)

    # Dead sticks poking up and out of the leaves, leaning away from the hedge.
    twigs = Piece("Twig", palette.TWIG)
    for i in range(7):
        length = rng.uniform(3.2, 4.6)
        x = -5.2 + i * 1.75 + rng.uniform(-0.5, 0.5)
        side = rng.choice((-1, 1))
        twigs.add(
            box((0.22, 0.22, length), bevel=0.05),
            place((x, side * rng.uniform(1.0, 1.8), rng.uniform(8.5, 11.0)), tilt_x=-side * rng.uniform(20, 45), tilt_y=rng.uniform(-20, 20)),
        )
    twigs.build(collection)


def hedge1(collection):
    _hedge(collection, 101, [9.0, 11.0, 7.5, 10.0])


def hedge2(collection):
    _hedge(collection, 102, [7.0, 9.5, 11.0, 8.0, 9.0])


def hedge3(collection):
    _hedge(collection, 103, [10.0, 7.5, 8.5, 10.5])


def _ridge_rock(collection, seed, width, depth, height):
    """A big rock: a broad base with a smaller, turned chunk on top, two stones leaning on it,
    and moss over the tops."""
    rng = random.Random(seed)
    turn = rng.uniform(-10, 10)
    base = box((width, depth, height * 0.62), bevel=width * 0.15, taper=0.85, jitter=width * 0.06, rng=rng)
    base_at = place((0, 0, height * 0.31), turn_z=turn)
    top = box((width * 0.72, depth * 0.7, height * 0.46), bevel=width * 0.13, taper=0.72, jitter=width * 0.06, rng=rng)
    top_at = place((width * 0.08, -depth * 0.06, height * 0.77), turn_z=turn + rng.uniform(12, 22), tilt_y=rng.uniform(3, 7))
    moss = Piece("Moss", palette.MOSS)
    moss.add(cap(base, min_up=0.8), base_at)
    moss.add(cap(top, min_up=0.8), top_at)
    stone = Piece("Rock", palette.STONE)
    stone.add(base, base_at)
    stone.add(top, top_at)
    stone.add(
        box((width * 0.5, depth * 0.55, height * 0.4), bevel=width * 0.09, taper=0.8, jitter=width * 0.04, rng=rng),
        place((width * 0.5, depth * 0.2, height * 0.18), turn_z=rng.uniform(10, 40), tilt_y=-8),
    )
    stone.add(
        box((width * 0.38, depth * 0.4, height * 0.26), bevel=width * 0.07, jitter=width * 0.03, rng=rng),
        place((-width * 0.46, -depth * 0.3, height * 0.12), turn_z=rng.uniform(-40, -10)),
    )
    stone.build(collection)
    moss.build(collection)


def ridge_rock1(collection):
    _ridge_rock(collection, 111, 10.0, 8.0, 13.0)


def ridge_rock2(collection):
    _ridge_rock(collection, 112, 12.0, 9.0, 9.0)


def _stone_wall(collection, seed, courses_at):
    """8 studs of old wall: rows of stone blocks, broken off at uneven heights (`courses_at`
    gives how many rows stand at each spot along it), with a block missing here and there
    and rubble at its foot. Some top blocks are mossy."""
    rng = random.Random(seed)
    length, depth, course = 8.0, 1.8, 1.15
    stones = Piece("Stone", palette.WALL_STONE)
    moss = Piece("Moss", palette.MOSS)
    for row in range(max(courses_at)):
        x = -length / 2
        if row % 2 == 1:
            x -= 0.9  # every other row is shifted, like real brickwork
        while x < length / 2 - 0.2:
            block = rng.uniform(1.6, 2.6)
            left, right = max(x, -length / 2), min(x + block, length / 2)
            middle = (left + right) / 2
            spot = min(int((middle + length / 2) / length * len(courses_at)), len(courses_at) - 1)
            standing = row < courses_at[spot]
            missing = 0 < row < courses_at[spot] - 1 and rng.random() < 0.06
            if right - left > 0.5 and standing and not missing:
                piece = box((right - left - 0.1, depth + rng.uniform(-0.12, 0.12), course - 0.1), bevel=0.12, jitter=0.05, rng=rng)
                where = place((middle, rng.uniform(-0.08, 0.08), row * course + course / 2), turn_z=rng.uniform(-2, 2))
                if row == courses_at[spot] - 1 and rng.random() < 0.45:
                    moss.add(cap(piece, min_up=0.8, lift=0.03, thickness=0.1), where)
                stones.add(piece, where)
            x += block
    for _ in range(7):
        size = rng.uniform(0.5, 1.0)
        stones.add(
            box((size, size * 0.9, size * 0.7), bevel=size * 0.2, jitter=size * 0.1, rng=rng),
            place((rng.uniform(-3.6, 3.6), rng.choice((-1, 1)) * rng.uniform(1.2, 1.8), size * 0.3), turn_z=rng.uniform(0, 90)),
        )
    stones.build(collection)
    moss.build(collection)


def stone_wall1(collection):
    _stone_wall(collection, 121, [5, 6, 4, 5, 6, 3])


def stone_wall2(collection):
    _stone_wall(collection, 122, [3, 5, 6, 6, 4, 5])


def _lamps(collection, iron, x, height, face):
    """Four lanterns: one on each side of the gate, on both faces of the gatehouse. Each hangs
    from a little arm on the tower's face (`face` is how far that face is from the middle);
    the arms go into the `iron` piece, which the caller builds."""
    lamps = Piece("Lamp", palette.LAMP)
    for side in (-1, 1):
        for y in (-1, 1):
            out = y * (face + 0.8)
            lamps.add(box((0.9, 0.9, 1.2), bevel=0.12), place((side * x, out, height)))
            iron.add(box((1.1, 1.1, 0.2), bevel=0.05), place((side * x, out, height + 0.7)))
            iron.add(box((0.15, 0.15, 0.3)), place((side * x, out, height + 0.95)))
            iron.add(box((0.25, 1.05, 0.25)), place((side * x, y * (face + 0.45), height + 1.15)))
    lamps.build(collection)


def log_gatehouse(collection):
    """Two log towers either side of the gate, joined by two beams with the sign between them,
    and a pyramid roof on each tower."""
    rng = random.Random(131)
    height, log, course = 20.0, 0.95, 1.5
    logs = Piece("Log", palette.WOOD)
    for side in (-1, 1):
        cx = side * TOWER_X
        logs.add(box((TOWER - 0.8, TOWER - 0.8, height), bevel=0.2), place((cx, 0, height / 2)))
        # Logs stacked around the tower, their ends crossing at the corners like a log cabin.
        for row in range(int(height / course)):
            z = row * course + course / 2
            long_along_x = row % 2 == 0
            for face in (-1, 1):
                along = TOWER + (0 if long_along_x else -0.2)
                across = TOWER - 0.2 if long_along_x else TOWER
                logs.add(
                    box((along, log, course - 0.15), bevel=0.3),
                    place((cx, face * (across / 2 - log / 2), z + rng.uniform(-0.03, 0.03))),
                )
                logs.add(
                    box((log, along, course - 0.15), bevel=0.3),
                    place((cx + face * (across / 2 - log / 2), 0, z + rng.uniform(-0.03, 0.03))),
                )
    # Two beams across the gap, with room for the sign between them.
    for z in (14.8, 18.9):
        logs.add(box((GATE + 2.0, 1.3, 1.3), bevel=0.25), place((0, 0, z)))
    logs.build(collection)

    roofs = Piece("Roof", palette.ROOF)
    for side in (-1, 1):
        roofs.add(box((TOWER + 1.6, TOWER + 1.6, 5.0), bevel=0.15, taper=0.1), place((side * TOWER_X, 0, height + 2.5)))
    roofs.build(collection)

    # The sign sits between the beams and sticks out a little in front of them.
    sign = Piece("Sign", palette.SIGN)
    sign.add(box((14.0, 1.7, 2.8), bevel=0.12), place((0, 0, 16.85)))
    sign.build(collection)
    iron = Piece("Iron", palette.IRON)
    _lamps(collection, iron, GATE / 2 + 1.3, 11.0, TOWER / 2)
    iron.build(collection)


def stone_gatehouse(collection):
    """Two stone pillars either side of the gate, with an iron arch and spikes between them."""
    rng = random.Random(141)
    stones = Piece("Stone", palette.WALL_STONE)
    for side in (-1, 1):
        cx = side * TOWER_X
        stones.add(box((TOWER, TOWER, 1.4), bevel=0.2, jitter=0.05, rng=rng), place((cx, 0, 0.7)))
        z = 1.4
        for block in range(6):
            tall = 2.5
            stones.add(
                box((TOWER - 1.4 + rng.uniform(-0.1, 0.1), TOWER - 1.4 + rng.uniform(-0.1, 0.1), tall - 0.08), bevel=0.25, jitter=0.06, rng=rng),
                place((cx, 0, z + tall / 2), turn_z=rng.uniform(-3, 3)),
            )
            z += tall
        stones.add(box((TOWER - 0.2, TOWER - 0.2, 1.0), bevel=0.2), place((cx, 0, z + 0.5)))
        stones.add(box((4.0, 4.0, 2.4), bevel=0.15, taper=0.12), place((cx, 0, z + 2.2)))
    stones.build(collection)

    iron = Piece("Iron", palette.IRON)
    inner = GATE / 2 + 0.2
    base = 14.4

    def arch(x):
        return base + 4.6 * (1 - (x / inner) ** 2)

    iron.add(box((GATE + 0.4, 0.35, 0.35)), place((0, 0, base)))
    steps = 8
    for i in range(steps):
        x0 = -inner + 2 * inner * i / steps
        x1 = -inner + 2 * inner * (i + 1) / steps
        z0, z1 = arch(x0), arch(x1)
        length = math.hypot(x1 - x0, z1 - z0)
        angle = -math.degrees(math.atan2(z1 - z0, x1 - x0))
        iron.add(box((length + 0.3, 0.35, 0.35)), place(((x0 + x1) / 2, 0, (z0 + z1) / 2), tilt_y=angle))
        if 0 < i:
            iron.add(box((0.4, 0.4, 0.9), taper=0.1), place((x0, 0, z0 + 0.55)))
    for x in [-6 + 1.5 * k for k in range(9)]:
        top = arch(x)
        iron.add(box((0.22, 0.22, top - base)), place((x, 0, (top + base) / 2)))
    _lamps(collection, iron, GATE / 2 + 1.3, 11.3, (TOWER - 1.4) / 2)
    iron.build(collection)

    sign = Piece("Sign", palette.SIGN)
    sign.add(box((10.0, 0.4, 2.2), bevel=0.1), place((0, 0, 16.1)))
    sign.build(collection)
