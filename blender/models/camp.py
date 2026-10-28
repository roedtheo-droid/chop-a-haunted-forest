"""The things in the camp (see src/server/Build/CampProps.luau and Systems/CampManager.luau),
each the same size as the parts version. Blender +Y is the front (-Z in Roblox).

  Bridge     the bridge over the river: 16 wide (X), 18 long (Y) with a 3-stud ramp at each
             end, its deck 1.2 up: "Deck" (planks and ramps), "Post" (rails, posts and the
             beams under it) and "Stone" (the footings on the banks)
  Well       a stone well 5 wide: "Stone", "Wood", "Roof", "Water", "Rope", "Bucket", "Metal"
  QuestBoard the notice board, its front at +Y: "Post", "Board", "Roof", "Note" and "Pin"
  Campfire   a ring of stones, logs leaning together and three logs to sit on: "Stone",
             "Log", "Ash", "Seat" and "Rings" (the light ends of the logs)
  Bench      a bench 5 wide, facing +Y: "Seat" (planks) and "Leg" (legs and arms)
  Signpost   the post the arrows hang on: "Post" and "Stone" (its base)
  SignArrow  one arrow board 5.4 long, pointing at +X: "Board", "Tip" and "Frame"
"""

import math
import random

from lib import palette
from lib.geometry import Piece, box, place


def bridge(collection):
    rng = random.Random(501)
    width, length, top, ramp, rail = 16.0, 18.0, 1.2, 3.0, 2.5
    deck = Piece("Deck", palette.WOOD)
    y = -length / 2
    while y < length / 2 - 0.05:
        plank = min(0.9, length / 2 - y)
        deck.add(box((width - rng.uniform(0, 0.3), plank - 0.08, 0.35), bevel=0.05), place((rng.uniform(-0.1, 0.1), y + plank / 2, top - 0.175)))
        y += plank
    slope = math.degrees(math.atan2(top, ramp))
    run = math.hypot(top, ramp)
    for side in (-1, 1):
        # Each ramp is planks laid on a slope from the deck down to the bank.
        for k in range(4):
            along = (k + 0.5) / 4 * run
            centre_y = side * (length / 2 + along * math.cos(math.radians(slope)))
            centre_z = top - along * math.sin(math.radians(slope)) - 0.18
            deck.add(box((width, run / 4 - 0.08, 0.35), bevel=0.05), place((0, centre_y, centre_z), tilt_x=-side * slope))
    deck.build(collection)
    posts = Piece("Post", palette.DARK_WOOD)
    for side in (-1, 1):
        x = side * (width / 2 - 0.3)
        posts.add(box((0.6, length, 0.6), bevel=0.08), place((x, 0, top + rail)))
        for offset in (-1, 0, 1):
            posts.add(box((0.8, 0.8, rail + 0.4), bevel=0.08), place((x, offset * (length / 2 - 0.4), top + (rail + 0.4) / 2 - 0.2)))
        for offset in (-0.5, 0.5):
            # Cross braces between the posts.
            posts.add(box((0.3, length / 2 - 0.8, 0.3)), place((x, offset * (length / 2 - 0.4), top + rail / 2), tilt_x=side * 18))
        posts.add(box((0.5, length, 0.6)), place((side * 6.0, 0, top - 0.65)))  # beams under the deck
    posts.build(collection)
    footing = Piece("Stone", palette.STONE)
    for side in (-1, 1):
        footing.add(box((width + 0.6, 1.4, 1.1), bevel=0.15, jitter=0.06, rng=rng), place((0, side * 7.6, 0.45)))
    footing.build(collection)


def well(collection):
    rng = random.Random(502)
    size, thick, height = 5.0, 0.8, 2.6
    stone = Piece("Stone", palette.STONE)
    # Courses of stone blocks around the square well.
    for course in range(3):
        z = course * (height / 3) + height / 6
        for side in range(4):
            along = -size / 2 + (0.4 if course % 2 else 0.0)
            while along < size / 2 - 0.3:
                block = min(rng.uniform(1.1, 1.7), size / 2 - along)
                length = block - 0.06
                middle = along + block / 2
                spot = [(middle, size / 2 - thick / 2), (size / 2 - thick / 2, middle), (middle, -size / 2 + thick / 2), (-size / 2 + thick / 2, middle)][side]
                dims = (length, thick, height / 3 - 0.06) if side % 2 == 0 else (thick, length, height / 3 - 0.06)
                stone.add(box(dims, bevel=0.08, jitter=0.03, rng=rng), place((spot[0], spot[1], z)))
                along += block
    stone.build(collection)
    wood = Piece("Wood", palette.DARK_WOOD)
    for side in (-1, 1):
        wood.add(box((0.6, 0.6, 5.6), bevel=0.06), place((side * (size / 2 - 0.3), 0, 2.8)))
    wood.add(box((size + 0.6, 0.4, 0.4), bevel=0.06), place((0, 0, 4.6)))  # the crank's axle
    wood.add(box((0.3, 0.3, 1.2)), place((size / 2 + 0.4, 0, 4.1)))
    wood.build(collection)
    roof = Piece("Roof", palette.ROOF)
    for side in (-1, 1):
        roof.add(box((size + 0.4, 2.0, 0.25), bevel=0.04), place((0, side * 0.75, 6.3), tilt_x=-side * 40))
    roof.build(collection)
    Piece("Water", palette.WATER).add(box((size - thick * 2, size - thick * 2, 0.2)), place((0, 0, height - 0.6))).build(collection)
    Piece("Rope", palette.ROPE).add(box((0.12, 0.12, 1.2)), place((0, 0, 3.9))).build(collection)
    Piece("Bucket", palette.WOOD).add(box((1.0, 1.0, 1.0), bevel=0.08, taper=0.85), place((0, 0, 2.9))).build(collection)
    Piece("Metal", palette.METAL).add(box((1.06, 1.06, 0.15)), place((0, 0, 3.1))).build(collection)


def quest_board(collection):
    rng = random.Random(503)
    posts = Piece("Post", palette.DARK_WOOD)
    for side in (-1, 1):
        posts.add(box((0.8, 0.8, 8.8), bevel=0.08), place((side * 3.6, 0, 4.4)))
    for z in (6.9, 2.3):
        posts.add(box((8.0, 0.6, 0.4), bevel=0.06), place((0, 0, z)))
    posts.build(collection)
    board = Piece("Board", palette.WOOD)
    for k in range(4):
        board.add(box((7.6, 0.4, 1.08), bevel=0.04), place((0, 0, 2.95 + k * 1.1)))
    board.build(collection)
    Piece("Roof", palette.ROOF).add(box((9.0, 2.4, 0.4), bevel=0.06), place((0, 0, 9.0), tilt_x=-15)).build(collection)
    notes = Piece("Note", palette.PAPER)
    pins = Piece("Pin", palette.PIN)
    for index in range(6):
        column, row = index % 3, index // 3
        x, z = -2.4 + column * 2.4, 5.7 - row * 2.1
        turn = rng.uniform(-8, 8)
        notes.add(box((1.6, 0.05, 1.6)), place((x, 0.25, z), tilt_y=turn))
        pins.add(box((0.25, 0.15, 0.25), bevel=0.04), place((x, 0.32, z + 0.55)))
    notes.build(collection)
    pins.build(collection)


def campfire(collection):
    rng = random.Random(504)
    stones = Piece("Stone", palette.STONE)
    for i in range(8):
        angle = (i + 1) * math.pi / 4
        stones.add(box((1.3, 1.3, 0.9), bevel=0.25, jitter=0.08, rng=rng), place((math.cos(angle) * 2.4, math.sin(angle) * 2.4, 0.45), turn_z=math.degrees(angle)))
    stones.build(collection)
    Piece("Ash", palette.ASH).add(box((3.4, 3.4, 0.15), bevel=0.3), place((0, 0, 0.08), turn_z=20)).build(collection)
    logs = Piece("Log", palette.WOOD)
    ends = Piece("Rings", palette.INNER_WOOD)
    for i in range(3):
        azimuth = (i + 1) * 120
        a = math.radians(azimuth)
        # Leaning in over the fire, their tops meeting in the middle.
        logs.add(box((0.7, 0.7, 3.0), bevel=0.1), place((math.cos(a) * 0.8, math.sin(a) * 0.8, 0.9), turn_z=azimuth, tilt_y=-35))
    for i in range(3):
        angle = (i + 1) * 2 * math.pi / 3 + math.pi / 6
        x, y = math.cos(angle) * 6.5, math.sin(angle) * 6.5
        seat = Piece(f"Seat_{i + 1}", palette.WOOD)
        turn = math.degrees(angle) + 90  # lying across the way to the fire
        seat.add(box((5.0, 1.6, 1.6), bevel=0.25), place((x, y, 0.8), turn_z=turn))
        seat.build(collection)
        for end in (-1, 1):
            t = math.radians(turn)
            ends.add(box((0.06, 1.25, 1.25)), place((x + end * math.cos(t) * 2.51, y + end * math.sin(t) * 2.51, 0.8), turn_z=turn))
    logs.build(collection)
    ends.build(collection)


def bench(collection):
    seat = Piece("Seat", palette.WOOD)
    for k in range(3):
        seat.add(box((5.0, 0.5, 0.4), bevel=0.05), place((0, -0.55 + k * 0.55, 1.6)))
    for k in range(2):
        seat.add(box((5.0, 0.3, 0.55), bevel=0.05), place((0, -0.75, 2.65 + k * 0.65)))
    seat.build(collection)
    legs = Piece("Leg", palette.DARK_WOOD)
    for side in (-1, 1):
        legs.add(box((0.4, 1.4, 1.4), bevel=0.06), place((side * 2, 0, 0.7)))
        legs.add(box((0.3, 0.3, 2.2), bevel=0.04), place((side * 2, -0.75, 2.5)))
        legs.add(box((0.35, 1.6, 0.25), bevel=0.04), place((side * 2.15, -0.1, 2.3)))  # armrests
    legs.build(collection)


def signpost(collection):
    post = Piece("Post", palette.DARK_WOOD)
    post.add(box((0.6, 0.6, 7.4), bevel=0.06), place((0, 0, 3.7)))
    post.add(box((0.9, 0.9, 0.4), bevel=0.06, taper=0.5), place((0, 0, 7.55), turn_z=45))
    post.build(collection)
    Piece("Stone", palette.STONE).add(box((1.6, 1.6, 0.6), bevel=0.15, jitter=0.05, rng=random.Random(506)), place((0, 0, 0.3))).build(collection)


def sign_arrow(collection):
    """One arrow board, centred on the origin, pointing at +X. The game writes on its two
    flat sides (+Y and -Y here)."""
    Piece("Board", palette.WOOD).add(box((5.4, 0.4, 1.1), bevel=0.04)).build(collection)
    Piece("Tip", palette.WOOD).add(box((0.78, 0.4, 0.78), bevel=0.04), place((2.7, 0, 0), tilt_y=45)).build(collection)
    frame = Piece("Frame", palette.DARK_WOOD)
    for z in (-0.6, 0.6):
        frame.add(box((5.5, 0.5, 0.12)), place((-0.05, 0, z)))
    frame.add(box((0.12, 0.5, 1.3)), place((-2.75, 0, 0)))
    frame.build(collection)
