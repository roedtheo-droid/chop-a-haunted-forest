"""The landmarks in the zones (see src/server/Build/Landmarks.luau), each the same size as
the parts version the game builds without it. Blender +Y is the front (-Z in Roblox).

  Tent           a canvas tent 7 long (X), door at -X: "Canvas", "Door", "Wood" (ridge,
                 poles, pegs) and "Rope"
  Dock           16 studs of deck along X (its top 1 stud up), posts down into the lake:
                 "Deck", "Step" (onto the beach, at +X) and "Post"
  Rowboat        a little boat along X (bow at +X): "Hull", "Trim", "Seat" and "Oar"
  WindmillTower  three stone levels, a broken roof slipping off, a fallen sail: "Tower",
                 "Moss", "Roof", "Dark" (door and windows), "Spar" and "Sail"
  WindmillSails  the sails on their hub, turning around X: "Hub", "Spar" and "Sail"
  IronFence      3 studs of iron fence along X: "Post" (the thick post at its start) and
                 "Iron" (a bar and the two rails)
  Crypt          a stone crypt 10 wide, front at +Y: "Stone" (its body), "Front" (pillars,
                 lintel and steps), "Roof", "Glow" (the light inside) and "Iron" (door bars)
  BossStone1-2   tall standing stones around the boss: "Stone", "Moss", and "Chunk" (a piece
                 broken off, on BossStone2)
"""

import math
import random

from lib import palette
from lib.geometry import Piece, box, cap, place
from mathutils import Matrix


def tent(collection):
    rng = random.Random(401)
    length, width, height = 7.0, 6.0, 4.0
    slant = math.hypot(width / 2, height)
    angle = math.degrees(math.atan2(width / 2, height))
    canvas = Piece("Canvas", palette.CANVAS)
    for side in (-1, 1):
        # Each side leans in, so the two meet in a ridge along the top.
        canvas.add(box((length, 0.3, slant), bevel=0.05), place((0, side * width / 4, height / 2), tilt_x=side * angle))
    # The back: a triangle made of three steps, each as wide as the tent is at its top.
    for i in range(3):
        top = (i + 1) * 1.3
        canvas.add(box((0.3, max(width * (1 - top / height), 0.4), 1.3)), place((length / 2 - 0.2, 0, top - 0.65)))
    canvas.build(collection)
    Piece("Door", palette.DARK).add(box((0.1, 1.6, 2.6)), place((-length / 2 + 0.6, 0, 1.3))).build(collection)
    wood = Piece("Wood", palette.DARK_WOOD)
    wood.add(box((length + 0.8, 0.25, 0.25)), place((0, 0, height + 0.05)))
    for x in (-1, 1):
        wood.add(box((0.25, 0.25, height + 0.6)), place((x * (length / 2 + 0.3), 0, (height + 0.6) / 2)))
    pegs = [(x * (length / 2 + 1.4), 0) for x in (-1, 1)] + [(x * 2.2, y * (width / 2 + 0.9)) for x in (-1, 1) for y in (-1, 1)]
    for x, y in pegs:
        wood.add(box((0.2, 0.2, 0.5), taper=0.4), place((x, y, 0.2), tilt_x=rng.uniform(-10, 10)))
    wood.build(collection)
    rope = Piece("Rope", palette.ROPE)
    for x, y in pegs:
        # From the peg up to the ridge's end or the canvas's edge.
        top = (math.copysign(length / 2 + 0.3, x), 0, height + 0.4) if y == 0 else (x, math.copysign(width / 2 - 0.2, y), 0.8)
        dx, dy, dz = top[0] - x, top[1] - y, top[2] - 0.35
        run = math.sqrt(dx * dx + dy * dy + dz * dz)
        direction = (dx / run, dy / run, dz / run)
        # A thin box from the peg to `top`: turned to point along `direction`.
        tilt = math.degrees(math.acos(direction[2]))
        azimuth = math.degrees(math.atan2(direction[1], direction[0]))
        rope.add(box((0.08, 0.08, run)), place(((x + top[0]) / 2, (y + top[1]) / 2, (0.35 + top[2]) / 2), turn_z=azimuth, tilt_y=tilt))
    rope.build(collection)


def dock(collection):
    rng = random.Random(402)
    length, deck_top = 16.0, 1.0
    deck = Piece("Deck", palette.WOOD)
    x = -length / 2
    while x < length / 2 - 0.05:
        plank = min(0.85, length / 2 - x)
        deck.add(box((plank - 0.08, 4.0 + rng.uniform(-0.1, 0.1), 0.4), bevel=0.05), place((x + plank / 2, rng.uniform(-0.05, 0.05), deck_top - 0.2 + rng.uniform(-0.02, 0.02))))
        x += plank
    deck.build(collection)
    step = Piece("Step", palette.WOOD)
    step.add(box((1.4, 4.0, 0.5), bevel=0.05), place((length / 2 + 0.7, 0, 0.25)))
    step.build(collection)
    posts = Piece("Post", palette.DARK_WOOD)
    for i in range(5):
        for side in (-1, 1):
            posts.add(box((0.6, 0.6, 1.8), bevel=0.08), place((length / 2 - i * 4, side * 2, 0.6)))
    for side in (-1, 1):
        posts.add(box((0.25, length, 0.3)), place((0, side * 2.05, deck_top - 0.55), turn_z=90))  # beams under the planks
        posts.add(box((0.6, 0.6, 1.0), bevel=0.1), place((-length / 2 + 0.5, side * 1.6, deck_top + 0.5)))  # bollards
        posts.add(box((0.75, 0.75, 0.15), bevel=0.04), place((-length / 2 + 0.5, side * 1.6, deck_top + 1.05)))
    posts.build(collection)


def rowboat(collection):
    hull = Piece("Hull", palette.WOOD)
    trim = Piece("Trim", palette.TRIM_RED)
    hull.add(box((6.0, 2.6, 0.3), bevel=0.06), place((0, 0, 0.15)))
    for side in (-1, 1):
        hull.add(box((5.4, 0.3, 1.0), bevel=0.05), place((-0.3, side * 1.3, 0.5), tilt_x=side * 10))
        trim.add(box((5.4, 0.4, 0.2), bevel=0.04), place((-0.3, side * 1.38, 1.05)))
        # The front narrows to a point.
        hull.add(box((1.9, 0.3, 1.0), bevel=0.05), place((3.1, side * 0.75, 0.5), turn_z=-side * 35))
        trim.add(box((1.9, 0.4, 0.2), bevel=0.04), place((3.1, side * 0.78, 1.05), turn_z=-side * 35))
    hull.add(box((0.3, 2.6, 1.0), bevel=0.05), place((-3.0, 0, 0.5)))
    hull.build(collection)
    trim.build(collection)
    seats = Piece("Seat", palette.INNER_WOOD)
    for x in (-1.2, 1.0):
        seats.add(box((0.6, 2.4, 0.2), bevel=0.04), place((x, 0, 0.75)))
    seats.build(collection)
    oars = Piece("Oar", palette.INNER_WOOD)
    for side in (-1, 1):
        oars.add(box((4.0, 0.15, 0.15)), place((0, side * 0.6, 1.0), turn_z=side * 8))
        oars.add(box((0.9, 0.45, 0.08), bevel=0.03), place((2.3, side * 0.85, 1.0), turn_z=side * 8))
    oars.build(collection)


def windmill_tower(collection):
    rng = random.Random(404)
    tower = Piece("Tower", palette.TOWER_STONE)
    moss = Piece("Moss", palette.MOSS)
    z = 0.0
    for size, height in [(10.0, 8.0), (8.5, 7.0), (7.0, 5.0)]:
        level = box((size, size, height), bevel=0.25, jitter=0.06, rng=rng)
        where = place((0, 0, z + height / 2), turn_z=rng.uniform(-2, 2))
        moss.add(cap(level, min_up=0.9, lift=0.03, thickness=0.12), where)
        tower.add(level, where)
        # Big corner stones, long and short in turn up each corner.
        for sx in (-1, 1):
            for sy in (-1, 1):
                course = 0
                stone_z = z + 0.1
                while stone_z < z + height - 0.6:
                    long_x = course % 2 == 0
                    w, d = (1.8, 1.1) if long_x else (1.1, 1.8)
                    tower.add(
                        box((w, d, 0.9), bevel=0.1, jitter=0.04, rng=rng),
                        place((sx * (size / 2 - w / 2 + 0.08), sy * (size / 2 - d / 2 + 0.08), stone_z + 0.45)),
                    )
                    stone_z += 1.0
                    course += 1
        z += height
    tower.build(collection)
    moss.build(collection)
    Piece("Roof", palette.ROOF).add(box((8.0, 8.0, 1.0), bevel=0.12), place((0.8, 0, z + 0.3), turn_z=-17, tilt_y=-14)).build(collection)
    dark = Piece("Dark", palette.DARK)
    dark.add(box((0.1, 3.0, 4.6)), place((-5.05, 0, 2.3)))
    dark.add(box((0.1, 1.2, 1.6)), place((-4.3, -1.6, 11)))
    dark.add(box((0.1, 1.1, 1.4)), place((-3.55, 1.2, 19)))
    dark.build(collection)
    # The broken-off sail lying on the ground.
    Piece("Spar", palette.DARK_WOOD).add(box((0.4, 8.0, 0.5)), place((-9, -6, 0.25), turn_z=-40)).build(collection)
    Piece("Sail", palette.SAIL).add(box((2.2, 6.0, 0.15)), place((-8.2, -6.9, 0.55), turn_z=-40, tilt_y=7)).build(collection)


def windmill_sails(collection):
    """The hub sits on the origin; the sails turn around X (the game spins them)."""
    hub = Piece("Hub", palette.DARK_WOOD)
    hub.add(box((1.6, 1.6, 1.6), bevel=0.3))
    hub.build(collection)
    spars = Piece("Spar", palette.DARK_WOOD)
    spars.add(box((1.0, 0.8, 0.8), bevel=0.1), place((0.9, 0, 0)))  # the axle going into the tower
    sails = Piece("Sail", palette.SAIL)
    for index, length in enumerate([8.0, 3.5, 8.0, 3.0], start=1):
        arm = Matrix.Rotation(index * math.pi / 2 + 0.4, 4, "X")
        spars.add(box((0.4, 0.5, length), bevel=0.05), arm @ Matrix.Translation((-0.3, 0, length / 2 + 0.6)))
        if length > 5:
            sails.add(box((0.15, 2.2, length * 0.8), bevel=0.03), arm @ Matrix.Translation((-0.3, -1.3, length / 2 + 1.2)))
            # Slats across the sail.
            for k in range(4):
                spars.add(box((0.2, 2.4, 0.15)), arm @ Matrix.Translation((-0.35, -1.3, 1.6 + k * length * 0.8 / 3.2)))
    spars.build(collection)
    sails.build(collection)


def iron_fence(collection):
    """One 3-stud section along X: a thick post at x = 0, a thin bar in the middle and two rails."""
    post = Piece("Post", palette.IRON)
    post.add(box((0.4, 0.4, 4.4), bevel=0.05), place((0, 0, 2.2)))
    post.add(box((0.55, 0.55, 0.5), taper=0.15), place((0, 0, 4.6), turn_z=45))
    post.build(collection)
    iron = Piece("Iron", palette.IRON)
    iron.add(box((0.18, 0.18, 3.8)), place((1.5, 0, 1.9)))
    iron.add(box((0.3, 0.3, 0.4), taper=0.1), place((1.5, 0, 3.95), turn_z=45))
    for z in (0.8, 3.4):
        iron.add(box((3.0, 0.2, 0.2)), place((1.5, 0, z)))
    iron.build(collection)


def crypt(collection):
    rng = random.Random(406)
    width, height, depth = 10.0, 8.0, 12.0
    stone = Piece("Stone", palette.DARK_STONE)
    stone.add(box((width, depth, height), bevel=0.2), place((0, 0, height / 2)))
    # Rows of stone blocks sticking out a little on the sides and back.
    for row in range(4):
        z = 1.0 + row * 1.9
        for side in (-1, 1):
            y = -depth / 2 + 0.4
            while y < depth / 2 - 0.6:
                block = rng.uniform(1.4, 2.4)
                stone.add(box((0.25, block - 0.15, 1.7), bevel=0.06), place((side * (width / 2 + 0.05), y + block / 2, z)))
                y += block
    # The pillars, lintel and steps at the front are their own part, so "Stone" is exactly the
    # crypt's body (the game sizes and places it by that).
    front = Piece("Front", palette.DARK_STONE)
    for side in (-1, 1):
        front.add(box((1.2, 1.2, 7.0), bevel=0.12), place((side * 2.6, depth / 2 + 0.6, 3.5)))
    front.add(box((7.0, 1.6, 1.0), bevel=0.12), place((0, depth / 2 + 0.6, 7.4)))
    for step in (1, 2):
        front.add(box((6.0, 1.4, 0.4), bevel=0.06), place((0, depth / 2 + 0.6 + step * 1.2, 0.2 + (2 - step) * 0.2)))
    front.build(collection)
    # The triangles under the roof at the front and back, in steps.
    for end in (-1, 1):
        for i in range(3):
            top = (i + 1) * 4.0 / 3
            stone.add(box((max(width * (1 - top / 4.0), 0.8), 0.6, 4.0 / 3), bevel=0.06), place((0, end * (depth / 2 - 0.3), height + top - 2.0 / 3)))
    stone.build(collection)
    roof = Piece("Roof", palette.DARK_STONE)
    slope = math.degrees(math.atan2(4.0, width / 2))
    run = math.hypot(4.0, width / 2) + 0.6
    for side in (-1, 1):
        # The ridge runs front to back (Y), so the gable faces the front.
        roof.add(box((run, depth + 1.2, 0.5), bevel=0.08), place((side * width / 4, 0, height + 2.0), tilt_y=side * slope))
    roof.build(collection)
    Piece("Glow", palette.GLOW_ORANGE).add(box((3.0, 0.1, 4.6)), place((0, depth / 2 + 0.05, 2.5))).build(collection)
    bars = Piece("Iron", palette.IRON)
    for i in range(1, 5):
        bars.add(box((0.2, 0.2, 4.6)), place((-1.5 + i * 0.6, depth / 2 + 0.2, 2.5)))
    bars.build(collection)


def _boss_stone(collection, seed, width, depth, height, broken):
    rng = random.Random(seed)
    stone = Piece("Stone", palette.DARK_STONE)
    moss = Piece("Moss", palette.MOSS)
    body = box((width, depth, height), bevel=0.25, taper=0.82, jitter=0.12, rng=rng)
    where = place((0, 0, height / 2))
    moss.add(cap(body, min_up=0.85, lift=0.03, thickness=0.14), where)  # before adding: that uses the body up
    stone.add(body, where)
    stone.build(collection)
    if broken:
        # A chunk broken off the top, lying against the foot (its own part, so "Stone" is just the stone).
        chunk = Piece("Chunk", palette.DARK_STONE)
        chunk.add(box((width * 0.6, depth * 0.8, 1.6), bevel=0.2, jitter=0.1, rng=rng), place((width * 0.7, depth * 0.3, 0.6), turn_z=25, tilt_y=-20))
        chunk.build(collection)
    moss.build(collection)


def boss_stone1(collection):
    _boss_stone(collection, 407, 3.0, 2.0, 10.0, False)


def boss_stone2(collection):
    _boss_stone(collection, 408, 2.8, 1.9, 8.0, True)
