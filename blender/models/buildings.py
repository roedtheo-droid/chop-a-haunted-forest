"""The Tool Shed and the sawmills (see src/server/Build/ToolShed.luau and SawmillBuilding.luau).

The game still builds the old parts there, made invisible: they do the bumping, the lights and
the smoke, and these models are what you see. Each model has a tiny "Pivot" box whose bottom
middle is the model's origin: the spot the game puts it on (see Assets.placed); the game
removes the box. Positions here are written in Roblox's axes, like the Luau code: x, y up,
and z, with +Z the front (the shed's door, the sawmill's open side). rbox() and at() turn
them into Blender's.

  ToolShedShell  the Tool Shed for Shop.BuildingSize 56 x 18 x 38, a 12 x 13 door and a 12-stud
                 roof: "Foundation", "Floor", "Wall" (six log walls, each its own part: the
                 game makes them solid so the camera stays inside), "Corner" (the crossed log
                 ends), "Doorway" (the door frame), "Door", "Roof" and "Gable" (solid too),
                 "Trim" (beams, posts, window frames), "Glass", "FlowerBox", "Flower" (three,
                 one per colour), "Leaf", "Porch", "Awning", "Chimney", "Lamp" and "Iron"
  Stove          the stove, its pipe up to the ceiling and firewood: "Stove", "Fire", "Pipe",
                 "Log" and "Rings"
  Armchair       facing -X: "Seat", "Arm" and "Leg"
  Barrel         2.4 wide and 3 tall: "Barrel" and "Hoop"
  Crate          a 2.4 cube: "Crate" and "Trim"
  UpgradeBench   the bench with the upgrades on it, 8 long along Z: "Top", "Leg", "Sack",
                 "Boot" and "Grinder"
  HangingLamp    a lamp on a chain up to the beam (its origin is in the lamp): "Lamp", "Iron"
  SawmillShed    the sawmill for Sawmill.BuildingSize 20 x 11 x 14 and a 6-stud roof: "Floor",
                 "Wall" (three), "Post", "Corner", "Roof", "Gable", "Trim", "Chimney", "Lamp"
                 and "Iron"
  SawTable       the saw's table and the conveyor belt out to the pad: "Table", "Top", "Belt",
                 "Rail", "Metal", "Iron", "Log" and "Rings"
  SawBlade       the round saw, 6 wide, turning around X (origin in its middle): "Blade",
                 "Teeth" and "Hub"
  WaterWheel     radius 5 and 2 wide, turning around X: "Rim", "Paddle", "Spoke", "Hub", "Shaft"
  Workshop       two sawhorses with a plank, a stack of boards and a hand saw: "Wood",
                 "Board" and "Metal"
  LogPile        six logs between two stakes: "Log", "Rings" and "Wood"
"""

import math
import random

from lib import palette
from lib.geometry import Piece, box, cylinder, place, wedge
from mathutils import Matrix, Vector

# What the models are made for (Config.Shop and Config.Sawmill in the game, and the
# constants at the top of ToolShed.luau and SawmillBuilding.luau).
SHED_W, SHED_H, SHED_D = 56.0, 18.0, 38.0
DOOR_W, DOOR_H = 12.0, 13.0
SHED_ROOF = 12.0
SHED_FLOOR = 0.7
MILL_W, MILL_H, MILL_D = 20.0, 11.0, 14.0
MILL_ROOF = 6.0
MILL_FLOOR = 0.4
TABLE_TOP = 3.4
SAW = 6.0
WHEEL_RADIUS, WHEEL_WIDTH, WHEEL_PIECES = 5.0, 2.0, 10
WALL = 1.0
COURSE = 1.5  # how tall each log in a wall is
ROOF_THICK = 0.45


def rbox(size, **kw):
    """A box sized in Roblox's axes: (x wide, y tall, z deep)."""
    return box((size[0], size[2], size[1]), **kw)


def at(x, y, z, turn=0.0, tilt=0.0, roll=0.0):
    """Put something at Roblox (x, y, z), tilted `tilt` degrees around X, then rolled around
    Z, then turned around Y (like CFrame.Angles)."""
    return place((x, -z, y), turn_z=turn, tilt_x=tilt, tilt_y=-roll)


def spin(angle, x, y, z):
    """A spot (x, y, z) on something turning around X, turned `angle` radians (a wheel)."""
    return Matrix.Rotation(angle, 4, "X") @ Matrix.Translation((x, -z, y))


def _pivot(collection):
    Piece("Pivot", palette.DARK_METAL).add(rbox((0.2, 0.2, 0.2)), at(0, 0.1, 0)).build(collection)


def _log_wall(piece, rng, length, along_x, cx, cz, y0, y1):
    """Logs stacked from y0 up to y1 on the walls' grid of courses, `length` long along X
    (or along Z), centred on (cx, cz) and exactly WALL thick, with a core behind them so
    there are no gaps."""

    def sized(along, tall, through):
        return (along, tall, through) if along_x else (through, tall, along)

    piece.add(rbox(sized(length, y1 - y0, WALL * 0.7)), at(cx, (y0 + y1) / 2, cz))
    k = math.floor(y0 / COURSE + 1e-6)
    while k * COURSE < y1 - 1e-6:
        lo, hi = max(k * COURSE, y0), min((k + 1) * COURSE, y1)
        if hi - lo > 0.25:
            tall = hi - lo - 0.1
            log = rbox(sized(length, tall, WALL * rng.uniform(0.93, 1.0)), bevel=min(0.32, tall * 0.3))
            piece.add(log, at(cx, (lo + hi) / 2 + rng.uniform(-0.02, 0.02), cz))
        k += 1
    return piece


def _corner(piece, x, z, y0, y1):
    """The log ends crossing at a corner, long along X and along Z in turn."""
    k = math.floor(y0 / COURSE + 1e-6)
    while k * COURSE < y1 - 1e-6:
        lo, hi = max(k * COURSE, y0), min((k + 1) * COURSE, y1)
        tall = hi - lo - 0.08
        size = (1.7, tall, 1.2) if k % 2 == 0 else (1.2, tall, 1.7)
        piece.add(rbox(size, bevel=min(0.32, tall * 0.3)), at(x, (lo + hi) / 2, z))
        k += 1


def _planks(piece, rng, width, depth, y, top, along_x, plank=1.2, joints=(8.0, 16.0), bevel=0.0):
    """A floor of planks `width` (X) by `depth` (Z) with its top at `top`, each plank `y`
    thick, laid along X (or Z) and broken into boards at random joints."""
    across, along = (depth, width) if along_x else (width, depth)
    a = -across / 2
    while a < across / 2 - 0.01:
        pw = min(plank, across / 2 - a)
        b = -along / 2
        while b < along / 2 - 0.01:
            length = min(rng.uniform(*joints), along / 2 - b)
            if along / 2 - b - length < joints[0] * 0.4:
                length = along / 2 - b  # no tiny board at the end
            middle_a, middle_b = a + pw / 2, b + length / 2
            if along_x:
                piece.add(rbox((length - 0.05, y, pw - 0.06), bevel=bevel), at(middle_b, top - y / 2, middle_a))
            else:
                piece.add(rbox((pw - 0.06, y, length - 0.05), bevel=bevel), at(middle_a, top - y / 2, middle_b))
            b += length
        a += pw


def _roof(roof, gable, trim, rng, width, depth, wall_h, rise, wall_x):
    """A gable roof the same shape as Blocky.roof: `width + 2` wide, its eaves `depth / 2 + 1`
    out from the middle at height wall_h and its ridge `rise` higher, with shingles, a ridge
    beam, edge boards and log gables at x = +-wall_x."""
    run = depth / 2 + 1
    slope = math.atan2(rise, run)
    length = math.hypot(rise, run)
    degrees = math.degrees(slope)
    span = width + 2
    rows = max(3, round(length / 1.5))
    for side in (1, -1):
        out = Vector((0, math.cos(slope), side * math.sin(slope)))  # straight out of the roof
        down = Vector((0, -math.sin(slope), side * math.cos(slope)))  # down the roof
        middle = Vector((0, wall_h + rise / 2, side * run / 2)) - out * (ROOF_THICK / 2)
        roof.add(rbox((span, ROOF_THICK, length)), at(middle.x, middle.y, middle.z, tilt=side * degrees))
        # Rows of shingles, each one's lower edge lifting a little over the row below.
        ridge = Vector((0, wall_h + rise, 0))
        for row in range(rows):
            spot = ridge + down * ((row + 0.5) * length / rows) + out * 0.1
            x = -span / 2
            while x < span / 2 - 0.01:
                board = min(rng.uniform(2.5, 5.0), span / 2 - x)
                if span / 2 - x - board < 1.2:
                    board = span / 2 - x
                roof.add(
                    rbox((board - 0.08, 0.18, length / rows + 0.3)),
                    at(x + board / 2, spot.y, spot.z, tilt=side * (degrees - 4)),
                )
                x += board
        # The boards along the eave and along both gable edges.
        trim.add(rbox((span, 0.5, 0.25)), at(0, wall_h - 0.2, side * (run + 0.05)))
        for gx in (-1, 1):
            edge = Vector((gx * (span / 2 + 0.15), wall_h + rise / 2, side * run / 2)) + out * 0.05
            trim.add(rbox((0.3, 0.7, length + 0.3)), at(edge.x, edge.y, edge.z, tilt=side * degrees))
    trim.add(rbox((span + 0.4, 0.6, 0.9), bevel=0.15), at(0, wall_h + rise + 0.1, 0))

    # Each gable: a core triangle (two ramps back to back) just under the roof, and logs
    # stepping up in front of it.
    under = ROOF_THICK / math.cos(slope) + 0.05  # how far under the roof's top its underside is
    peak = rise - under
    core_run = run * peak / rise
    for gx in (-wall_x, wall_x):
        gable.add(wedge((WALL * 0.7, core_run, peak)), at(gx, wall_h, core_run / 2, turn=180))
        gable.add(wedge((WALL * 0.7, core_run, peak)), at(gx, wall_h, -core_run / 2))
        k = 0
        while True:
            lo, hi = wall_h + k * COURSE, wall_h + (k + 1) * COURSE
            half = run * (peak - (hi - wall_h)) / rise
            if half < 0.8:
                break
            tall = COURSE - 0.1
            gable.add(rbox((WALL * rng.uniform(0.93, 1.0), tall, half * 2), bevel=0.3), at(gx, (lo + hi) / 2, 0))
            k += 1


def _chimney(piece, rng, x, z, size, y0, y1):
    """A stone chimney from y0 to y1: courses of two stones, laid one way and then the other,
    and a cap."""
    piece.add(rbox((size * 0.9, y1 - y0, size * 0.9)), at(x, (y0 + y1) / 2, z))
    y, course = y0, 0
    while y < y1 - 0.2:
        tall = min(rng.uniform(0.75, 0.95), y1 - y)
        for half in (-1, 1):
            if course % 2 == 0:
                size_ = (size / 2 - 0.05, tall - 0.06, size)
                spot = (x + half * size / 4, z)
            else:
                size_ = (size, tall - 0.06, size / 2 - 0.05)
                spot = (x, z + half * size / 4)
            piece.add(rbox(size_, bevel=0.08, jitter=0.03, rng=rng), at(spot[0], y + tall / 2, spot[1]))
        y += tall
        course += 1
    piece.add(rbox((size + 0.5, 0.4, size + 0.5), bevel=0.08), at(x, y1 + 0.2, z))
    piece.add(rbox((size - 0.6, 0.5, size - 0.6), bevel=0.08), at(x, y1 + 0.6, z))


def _lantern(lamp, iron, x, y, z, wall_z=None):
    """A lantern: a glowing box in an iron cap and base, on an arm from the wall at wall_z."""
    lamp.add(rbox((0.8, 1.0, 0.8), bevel=0.1), at(x, y, z))
    iron.add(rbox((1.1, 0.3, 1.1), bevel=0.06, taper=0.6), at(x, y + 0.65, z))
    iron.add(rbox((0.9, 0.15, 0.9), bevel=0.03), at(x, y - 0.55, z))
    for sx in (-1, 1):
        for sz in (-1, 1):
            iron.add(rbox((0.1, 1.0, 0.1)), at(x + sx * 0.42, y, z + sz * 0.42))
    if wall_z is not None:
        iron.add(rbox((0.2, 0.2, abs(z - wall_z) + 0.2)), at(x, y + 0.9, (z + wall_z) / 2))
        iron.add(rbox((0.15, 0.25, 0.15)), at(x, y + 0.85, z))


def _chain(iron, x, y0, y1, z):
    """A chain of links from y0 up to y1."""
    y, link = y0, 0
    while y < y1 - 0.2:
        size = (0.08, 0.45, 0.26) if link % 2 == 0 else (0.26, 0.45, 0.08)
        iron.add(rbox(size), at(x, y + 0.2, z))
        y += 0.38
        link += 1


def _log(piece, rings, length, thick, x, y, z, along_x, rng):
    """A square log with soft edges and light rings on both ends."""
    size = (length, thick, thick) if along_x else (thick, thick, length)
    piece.add(rbox(size, bevel=thick * 0.25, jitter=0.02, rng=rng), at(x, y, z))
    for end in (-1, 1):
        ring = (0.06, thick * 0.7, thick * 0.7) if along_x else (thick * 0.7, thick * 0.7, 0.06)
        if along_x:
            rings.add(rbox(ring), at(x + end * (length / 2 + 0.01), y, z))
        else:
            rings.add(rbox(ring), at(x, y, z + end * (length / 2 + 0.01)))


# ---------------------------------------------------------------------------------------
# The Tool Shed
# ---------------------------------------------------------------------------------------


def _window(glass, trim, flower_box, flowers, leaf, rng, x, y, width, height, wall_z):
    """A window on both faces of the front wall, like ToolShed.luau's addWindow: glass, a
    dark frame with a cross, and (outside) a flower box."""
    for face in (1, -1):
        z = wall_z + face * (WALL / 2 + 0.05)
        glass.add(rbox((width, height, 0.1)), at(x, y, z))
        fz = z + face * 0.1
        trim.add(rbox((width + 0.6, 0.4, 0.2), bevel=0.05), at(x, y + height / 2, fz))
        trim.add(rbox((width + 0.6, 0.4, 0.2), bevel=0.05), at(x, y - height / 2, fz))
        trim.add(rbox((0.4, height, 0.2), bevel=0.05), at(x - width / 2, y, fz))
        trim.add(rbox((0.4, height, 0.2), bevel=0.05), at(x + width / 2, y, fz))
        trim.add(rbox((0.3, height, 0.2)), at(x, y, fz))
        trim.add(rbox((width, 0.3, 0.2)), at(x, y, fz))
    box_z = wall_z + WALL / 2 + 0.6
    box_y = y - height / 2 - 0.6
    flower_box.add(rbox((width + 0.6, 0.8, 1.0), bevel=0.08), at(x, box_y, box_z))
    for k in range(7):
        leaf.add(rbox((1.1, 0.4, 0.6), bevel=0.12), at(x - width / 2 + (k + 0.5) * width / 7, box_y + 0.5, box_z + rng.uniform(-0.1, 0.1)))
    for index in range(1, 6):
        fx = x - width / 2 + index * width / 6
        flowers[(index - 1) % len(flowers)].add(rbox((0.6, 0.5, 0.6), bevel=0.15), at(fx, box_y + 0.75, box_z, turn=rng.uniform(0, 45)))


def tool_shed_shell(collection):
    rng = random.Random(701)
    w, h, d = SHED_W, SHED_H, SHED_D
    front = d / 2 - WALL / 2  # the middle of the front wall
    side = (w - DOOR_W) / 2  # each piece of wall beside the door
    _pivot(collection)

    # A low stone foundation: stones around the edge, a slab inside.
    fw, fd = w + 0.6, d + 0.6
    foundation = Piece("Foundation", palette.STONE)
    foundation.add(rbox((fw - 0.4, 0.6, fd - 0.4)), at(0, 0.3, 0))
    for along_x, length, fixed in ((True, fw, fd), (False, fd - 0.9, fw)):
        for sign in (-1, 1):
            a = -length / 2
            while a < length / 2 - 0.01:
                stone = min(rng.uniform(1.4, 2.4), length / 2 - a)
                size = (stone - 0.06, 0.6, 0.45) if along_x else (0.45, 0.6, stone - 0.06)
                spot = (a + stone / 2, sign * (fixed / 2 - 0.225)) if along_x else (sign * (fixed / 2 - 0.225), a + stone / 2)
                foundation.add(rbox(size, bevel=0.08), at(spot[0], 0.3, spot[1]))
                a += stone
    foundation.build(collection)

    floor = Piece("Floor", palette.WOOD)
    _planks(floor, rng, w - 2, d - 2, 0.2, SHED_FLOOR, along_x=True)
    floor.build(collection)

    # The six log walls, each its own part (the game makes them solid).
    walls = [
        (w, True, 0, -front, 0, h),  # back
        (d, False, -w / 2 + WALL / 2, 0, 0, h),  # left
        (d, False, w / 2 - WALL / 2, 0, 0, h),  # right
        (side, True, -DOOR_W / 2 - side / 2, front, 0, h),  # front, left of the door
        (side, True, DOOR_W / 2 + side / 2, front, 0, h),  # front, right of the door
        (DOOR_W, True, 0, front, DOOR_H, h),  # above the door
    ]
    for length, along_x, cx, cz, y0, y1 in walls:
        _log_wall(Piece("Wall", palette.WOOD), rng, length, along_x, cx, cz, y0, y1).build(collection)
    corners = Piece("Corner", palette.INNER_WOOD)
    for cx in (-w / 2, w / 2):
        for cz in (-d / 2, d / 2):
            _corner(corners, cx, cz, 0, h)
    corners.build(collection)

    # The door frame (the game checks its size against Config.Shop.DoorWidth and DoorHeight)
    # and the two doors standing wide open, flat out to the sides of the porch.
    doorway = Piece("Doorway", palette.DARK_WOOD)
    for sx in (-1, 1):
        doorway.add(rbox((1.0, DOOR_H, WALL + 0.4), bevel=0.1), at(sx * (DOOR_W / 2 + 0.5), DOOR_H / 2, front))
    doorway.add(rbox((DOOR_W + 2, 1.0, WALL + 0.4), bevel=0.1), at(0, DOOR_H + 0.5, front))
    doorway.build(collection)
    door = Piece("Door", palette.WOOD)
    iron = Piece("Iron", palette.IRON)
    leaf_w = DOOR_W / 2
    door_h = DOOR_H - 0.4
    for sx in (-1, 1):
        x = sx * (DOOR_W / 2 + 0.3)
        z0 = d / 2 + 0.2
        for k in range(5):
            pw = leaf_w / 5
            door.add(rbox((0.3, door_h - rng.uniform(0, 0.15), pw - 0.06), bevel=0.04), at(x, 0.2 + door_h / 2, z0 + pw * (k + 0.5)))
        # Two battens and a brace between them, on the side away from the doorway.
        bx = x + sx * 0.22
        for y in (2.2, door_h - 1.8):
            door.add(rbox((0.15, 0.6, leaf_w - 0.3), bevel=0.04), at(bx, y, z0 + leaf_w / 2))
        brace_len = math.hypot(door_h - 4.0, leaf_w - 1.0)
        brace = math.degrees(math.atan2(door_h - 4.0, leaf_w - 1.0))
        door.add(rbox((0.15, 0.5, brace_len), bevel=0.04), at(bx, door_h / 2 + 0.2, z0 + leaf_w / 2, tilt=brace))
        for y in (2.2, door_h - 1.8):
            iron.add(rbox((0.2, 0.35, 1.2)), at(bx + sx * 0.05, y, z0 + 0.5))
    door.build(collection)

    roof = Piece("Roof", palette.ROOF)
    gable = Piece("Gable", palette.WOOD)
    trim = Piece("Trim", palette.DARK_WOOD)
    _roof(roof, gable, trim, rng, w, d, h, SHED_ROOF, w / 2 - WALL / 2)
    roof.build(collection)
    gable.build(collection)

    # Beams across the room for the hanging lamps (ToolShed.luau's beamHeight).
    for z in (-d * 0.05, d * 0.27):
        trim.add(rbox((w - 2, 0.8, 0.8), bevel=0.12), at(0, h - 0.4, z))

    # A window on each side of the door, sized like ToolShed.luau's.
    glass = Piece("Glass", palette.WINDOW)
    flower_box = Piece("FlowerBox", palette.WOOD)
    leaf = Piece("Leaf", palette.GRASS_TUFT)
    flowers = [Piece("Flower", palette.TRIM_RED), Piece("Flower", palette.LILY_FLOWER), Piece("Flower", palette.YELLOW)]
    window_w, window_h = w * 0.16, h * 0.33
    window_y = max(6.0, h * 0.42)
    for sx in (-1, 1):
        _window(glass, trim, flower_box, flowers, leaf, rng, sx * (DOOR_W / 2 + side / 2), window_y, window_w, window_h, front)
    glass.build(collection)
    flower_box.build(collection)
    leaf.build(collection)
    for flower in flowers:
        flower.build(collection)

    # The porch: a plank deck, two posts and a little sloping roof just above the door.
    porch = Piece("Porch", palette.WOOD)
    porch_w = DOOR_W + 8
    porch.add(rbox((porch_w - 0.2, 0.45, 3.8)), at(0, 0.225, d / 2 + 2))
    for k in range(4):
        porch.add(rbox((porch_w, 0.25, 0.94), bevel=0.04), at(0, SHED_FLOOR - 0.125, d / 2 + 0.5 + k))
    porch.build(collection)
    porch_top = min(h - 0.6, DOOR_H + 1.4)
    awning = Piece("Awning", palette.ROOF)
    awning.add(rbox((DOOR_W + 7, 0.5, 5)), at(0, porch_top, d / 2 + 2.2, tilt=15))
    for row in range(3):
        along = -2.5 + (row + 0.5) * 5 / 3
        spot_y = porch_top + 0.3 - along * math.sin(math.radians(15))
        spot_z = d / 2 + 2.2 + along * math.cos(math.radians(15))
        awning.add(rbox((DOOR_W + 7, 0.16, 5 / 3 + 0.25)), at(0, spot_y, spot_z, tilt=11))
    awning.build(collection)
    for sx in (-1, 1):
        post_h = porch_top - 0.4
        trim.add(rbox((0.6, post_h, 0.6), bevel=0.08), at(sx * (DOOR_W / 2 + 3), post_h / 2, d / 2 + 3.9))
        trim.add(rbox((0.35, 1.8, 0.35)), at(sx * (DOOR_W / 2 + 3), post_h - 0.9, d / 2 + 3.3, tilt=40))
    trim.build(collection)

    # The stone chimney over the stove, sticking out of the roof.
    chimney = Piece("Chimney", palette.STONE)
    size = max(3.0, w * 0.07)
    tall = SHED_ROOF + 1
    _chimney(chimney, rng, w / 2 - 3, -d / 2 + 5, size, h - 2, h + tall - 2)
    chimney.build(collection)

    # A lantern on each side of the door.
    lamp = Piece("Lamp", palette.LAMP)
    for sx in (-1, 1):
        _lantern(lamp, iron, sx * (DOOR_W / 2 + 1.6), DOOR_H * 0.75, d / 2 + 0.6, wall_z=d / 2)
    lamp.build(collection)
    iron.build(collection)


def stove(collection):
    """Its origin is the floor under its middle. The fire faces -X, into the room."""
    rng = random.Random(702)
    _pivot(collection)
    body = Piece("Stove", palette.DARK_METAL)
    for sx in (-1, 1):
        for sz in (-1, 1):
            body.add(rbox((0.4, 0.45, 0.4), bevel=0.05), at(sx * 1.2, 0.225, sz * 1.2))
    body.add(rbox((2.8, 2.8, 2.8), bevel=0.15), at(0, 1.85, 0))
    body.add(rbox((3.0, 0.3, 3.0), bevel=0.06), at(0, 3.45, 0))
    body.add(rbox((0.2, 1.8, 2.2), bevel=0.05), at(-1.45, 1.6, 0))
    body.add(rbox((0.3, 0.25, 0.8), bevel=0.05), at(-1.65, 2.35, 0.5))  # the door's handle
    body.build(collection)
    Piece("Fire", palette.GLOW_ORANGE).add(rbox((0.1, 1.2, 1.6)), at(-1.56, 1.6, 0)).build(collection)
    pipe = Piece("Pipe", palette.DARK_METAL)
    top = SHED_H - SHED_FLOOR  # the ceiling, from the floor
    pipe.add(cylinder(0.4, top - 3.6, 8), at(0, (3.6 + top) / 2, 0))
    pipe.add(cylinder(0.52, 0.3, 8), at(0, 3.8, 0))
    pipe.add(cylinder(0.48, 0.2, 8), at(0, 9.0, 0))
    pipe.build(collection)
    logs = Piece("Log", palette.WOOD)
    rings = Piece("Rings", palette.INNER_WOOD)
    for oy, oz in ((0, 0), (0, 1), (0.9, 0.5)):
        _log(logs, rings, 2.4, 0.86, 0, 0.45 + oy, 3.2 + oz, True, rng)
    logs.build(collection)
    rings.build(collection)


def armchair(collection):
    """Its origin is the floor under its middle. It faces -X; its back is at +X."""
    _pivot(collection)
    seat = Piece("Seat", palette.CHAIR)
    seat.add(rbox((2.5, 0.6, 2.3), bevel=0.22), at(-0.2, 1.25, 0))
    seat.add(rbox((0.7, 2.0, 2.3), bevel=0.22), at(0.85, 2.45, 0, roll=-8))
    seat.build(collection)
    arm = Piece("Arm", palette.CHAIR)
    arm.add(rbox((3.0, 0.7, 3.0), bevel=0.15), at(0, 0.65, 0))
    arm.add(rbox((0.6, 3.2, 3.0), bevel=0.2), at(1.2, 1.9, 0))
    for sz in (-1, 1):
        arm.add(rbox((2.8, 0.9, 0.6), bevel=0.22), at(-0.1, 1.85, sz * 1.25))
    arm.build(collection)
    leg = Piece("Leg", palette.DARK_WOOD)
    for sx in (-1, 1):
        for sz in (-1, 1):
            leg.add(rbox((0.35, 0.3, 0.35), bevel=0.05), at(sx * 1.25, 0.15, sz * 1.25))
    leg.build(collection)


def barrel(collection):
    """Its origin is the floor under its middle: 3 tall, about 2.4 wide at the middle."""
    _pivot(collection)
    staves = Piece("Barrel", palette.WOOD)
    hoops = Piece("Hoop", palette.DARK_METAL)
    sides, height = 12, 3.0
    r_end, r_mid = 0.98, 1.1
    half = height / 2
    lean = math.degrees(math.atan2(r_mid - r_end, half))
    stave_w = 2 * r_mid * math.tan(math.pi / sides) * 1.06
    staves.add(cylinder(r_end - 0.05, height - 0.1, sides), at(0, height / 2, 0))
    for k in range(sides):
        a = k * 2 * math.pi / sides
        turn = 90 - math.degrees(a)
        r = (r_end + r_mid) / 2
        for bottom, tilt in ((True, lean), (False, -lean)):
            y = half / 2 if bottom else half + half / 2
            staves.add(
                rbox((stave_w, half + 0.06, 0.18), bevel=0.03),
                at(math.cos(a) * r, y, math.sin(a) * r, turn=turn, tilt=tilt),
            )
    for y in (0.35, half, height - 0.35):
        r = r_end + (r_mid - r_end) * (1 - abs(y - half) / half) + 0.1
        for k in range(sides):
            a = k * 2 * math.pi / sides
            hoops.add(rbox((2 * r * math.tan(math.pi / sides) * 1.08, 0.22, 0.06)), at(math.cos(a) * r, y, math.sin(a) * r, turn=90 - math.degrees(a)))
    staves.build(collection)
    hoops.build(collection)


def crate(collection):
    """Its origin is the floor under its middle: a 2.4 cube."""
    _pivot(collection)
    body = Piece("Crate", palette.CRATE)
    body.add(rbox((2.2, 2.2, 2.2)), at(0, 1.2, 0))
    for k in range(3):
        y = 0.45 + k * 0.75
        for sx in (-1, 1):
            body.add(rbox((0.1, 0.66, 2.0), bevel=0.03), at(sx * 1.12, y, 0))
            body.add(rbox((2.0, 0.66, 0.1), bevel=0.03), at(0, y, sx * 1.12))
        body.add(rbox((2.0, 0.1, 0.62), bevel=0.03), at(0, 2.32, -0.72 + k * 0.72))
    body.build(collection)
    trim = Piece("Trim", palette.CRATE)
    for sx in (-1, 1):
        for sz in (-1, 1):
            trim.add(rbox((0.3, 2.4, 0.3), bevel=0.05), at(sx * 1.05, 1.2, sz * 1.05))
    for y in (0.15, 2.25):
        for s in (-1, 1):
            trim.add(rbox((1.8, 0.3, 0.3), bevel=0.05), at(0, y, s * 1.05))
            trim.add(rbox((0.3, 0.3, 1.8), bevel=0.05), at(s * 1.05, y, 0))
    trim.build(collection)


def upgrade_bench(collection):
    """Its origin is the floor under its middle; it's 8 long along Z, by the left wall."""
    rng = random.Random(705)
    _pivot(collection)
    top = Piece("Top", palette.WOOD)
    for x in (-1.2, 0, 1.2):
        top.add(rbox((1.15, 0.4, 8.0), bevel=0.05), at(x, 3.0, 0))
    top.add(rbox((3.0, 0.15, 7.0), bevel=0.03), at(0, 0.7, 0))  # a shelf underneath
    top.build(collection)
    leg = Piece("Leg", palette.DARK_WOOD)
    for sx in (-1, 1):
        for sz in (-1, 1):
            leg.add(rbox((0.4, 2.8, 0.4), bevel=0.05), at(sx * 1.5, 1.4, sz * 3.6))
        leg.add(rbox((0.25, 0.25, 7.2)), at(sx * 1.5, 0.55, 0))
    # The grindstone's frame and crank.
    for sx in (-1, 1):
        leg.add(rbox((0.2, 1.15, 0.25)), at(sx * 0.45, 3.2 + 0.58, 2.6))
    leg.add(rbox((1.5, 0.15, 0.15)), at(0, 4.2, 2.6))
    leg.add(rbox((0.15, 0.7, 0.15)), at(0.8, 3.9, 2.6))
    leg.build(collection)
    sack = Piece("Sack", palette.SACK)
    sack.add(rbox((1.5, 1.4, 1.3), bevel=0.4, jitter=0.05, rng=rng), at(0, 3.2 + 0.7, -2.6))
    sack.add(rbox((0.7, 0.35, 0.6), bevel=0.1, taper=0.7), at(0, 3.2 + 1.55, -2.6))
    sack.add(rbox((0.9, 0.3, 0.8), bevel=0.12), at(0, 3.2 + 1.8, -2.6, turn=20))
    sack.build(collection)
    boots = Piece("Boot", palette.BOOT)
    for sz in (-0.4, 0.4):
        boots.add(rbox((0.6, 0.8, 0.55), bevel=0.1), at(-0.25, 3.2 + 0.6, sz))
        boots.add(rbox((1.1, 0.35, 0.55), bevel=0.12), at(0.05, 3.2 + 0.18, sz))
    boots.build(collection)
    Piece("Grinder", palette.STONE).add(cylinder(1.0, 0.6, 14), at(0, 4.2, 2.6, roll=-90)).build(collection)


def hanging_lamp(collection):
    """Its origin is in the lamp; the chain reaches up to the beam above."""
    _pivot(collection)
    lamp = Piece("Lamp", palette.LAMP)
    iron = Piece("Iron", palette.DARK_METAL)
    _lantern(lamp, iron, 0, 0, 0)
    # ToolShed.luau: the lamps hang at 9 studs, under beams 17.6 up, on a chain from 0.6 above
    # the lamp to 0.4 under the beam.
    lamp_y = min(9.0, SHED_H - 0.4 - 2.6)
    top = (SHED_H - 0.4 - 0.4) - lamp_y
    _chain(iron, 0, 0.6, top, 0)
    lamp.build(collection)
    iron.build(collection)


# ---------------------------------------------------------------------------------------
# The sawmills
# ---------------------------------------------------------------------------------------


def sawmill_shed(collection):
    rng = random.Random(711)
    w, h, d = MILL_W, MILL_H, MILL_D
    _pivot(collection)
    floor = Piece("Floor", palette.WOOD)
    _planks(floor, rng, w, d, MILL_FLOOR, MILL_FLOOR, along_x=False, plank=1.25, joints=(5.0, 9.0))
    floor.build(collection)
    for length, along_x, cx, cz in ((w, True, 0, -d / 2 + WALL / 2), (d, False, -w / 2 + WALL / 2, 0), (d, False, w / 2 - WALL / 2, 0)):
        _log_wall(Piece("Wall", palette.WOOD), rng, length, along_x, cx, cz, 0, h).build(collection)
    corners = Piece("Corner", palette.INNER_WOOD)
    for cx in (-w / 2, w / 2):
        _corner(corners, cx, -d / 2, 0, h)
    corners.build(collection)

    # The open front: two thick posts, a beam across the top and braces in the corners.
    post = Piece("Post", palette.DARK_WOOD)
    for sx in (-1, 1):
        post.add(rbox((1.4, h, 1.4), bevel=0.15), at(sx * (w / 2 - 0.7), h / 2, d / 2 - 0.7))
        post.add(rbox((0.4, 2.6, 0.4), bevel=0.05), at(sx * (w / 2 - 2.1), h - 2.1, d / 2 - 0.7, roll=sx * 45))
    post.add(rbox((w, 1.4, 1.4), bevel=0.15), at(0, h - 0.7, d / 2 - 0.7))
    post.build(collection)

    roof = Piece("Roof", palette.ROOF)
    gable = Piece("Gable", palette.WOOD)
    trim = Piece("Trim", palette.DARK_WOOD)
    _roof(roof, gable, trim, rng, w, d, h, MILL_ROOF, w / 2 - WALL / 2)
    roof.build(collection)
    gable.build(collection)
    trim.build(collection)

    chimney = Piece("Chimney", palette.STONE)
    _chimney(chimney, rng, -w / 2 + 3, -d / 2 + 2.5, 2.4, h - 1, h + 7)
    chimney.build(collection)

    # A lantern hanging from the front beam.
    lamp = Piece("Lamp", palette.LAMP)
    iron = Piece("Iron", palette.DARK_METAL)
    _lantern(lamp, iron, 0, h - 3.1, d / 2 - 0.7)
    _chain(iron, 0, h - 3.1 + 0.6, h - 1.4, d / 2 - 0.7)
    lamp.build(collection)
    iron.build(collection)


def saw_table(collection):
    """In the sawmill's frame (its origin is the middle of the sawmill's floor plan)."""
    rng = random.Random(712)
    _pivot(collection)
    d = MILL_D
    back, front = -d / 2 + 2, 2.0
    length = front - back
    middle = (back + front) / 2
    table = Piece("Table", palette.DARK_WOOD)
    for sx in (-1, 1):
        for z in (back + 0.3, front - 0.3):
            table.add(rbox((0.4, TABLE_TOP - MILL_FLOOR, 0.4), bevel=0.05), at(sx * 1.5, (TABLE_TOP + MILL_FLOOR) / 2, z))
        table.add(rbox((0.25, 0.5, length), bevel=0.04), at(sx * 1.575, TABLE_TOP - 0.25, middle))
        table.add(rbox((0.25, 0.25, length - 0.6)), at(sx * 1.5, 1.2, middle))
    for z in (back + 0.125, front - 0.125):
        table.add(rbox((3.4, 0.5, 0.25), bevel=0.04), at(0, TABLE_TOP - 0.25, z))
    table.build(collection)
    top = Piece("Top", palette.WOOD)
    blade_z = middle - 1  # SawmillBuilding.luau's sawZ
    for x in (-1.52, -0.76, 0.76, 1.52):
        top.add(rbox((0.72, 0.3, length + 0.2), bevel=0.03), at(x, TABLE_TOP + 0.15, middle))
    # The middle plank has a slot for the blade.
    slot_end = blade_z + SAW / 2 + 0.1
    for x in (-0.27, 0.27):
        top.add(rbox((0.2, 0.3, length + 0.2), bevel=0.02), at(x, TABLE_TOP + 0.15, middle))
    top.add(rbox((0.36, 0.3, front + 0.1 - slot_end)), at(0, TABLE_TOP + 0.15, (slot_end + front + 0.1) / 2))
    top.build(collection)

    # The conveyor belt from the table out to the pad in front, on legs, with rollers.
    belt_back, belt_front = front, d / 2 + 0.6
    belt_len = belt_front - belt_back
    belt_z = (belt_back + belt_front) / 2
    belt_top = TABLE_TOP - 0.2
    belt = Piece("Belt", palette.BELT)
    belt.add(rbox((2.6, 0.3, belt_len)), at(0, belt_top - 0.15, belt_z))
    k = 0
    while belt_back + 0.35 + k * 0.7 < belt_front - 0.2:
        belt.add(rbox((2.5, 0.08, 0.15)), at(0, belt_top + 0.04, belt_back + 0.35 + k * 0.7))
        k += 1
    belt.build(collection)
    rail = Piece("Rail", palette.HAZARD)
    for sx in (-1, 1):
        rail.add(rbox((0.3, 0.7, belt_len), bevel=0.05), at(sx * 1.45, belt_top - 0.1, belt_z))
    rail.build(collection)
    iron = Piece("Iron", palette.DARK_METAL)
    for sx in (-1, 1):
        for z in (belt_back + 0.4, belt_front - 0.4):
            iron.add(rbox((0.4, belt_top - MILL_FLOOR, 0.4)), at(sx * 1.2, (belt_top + MILL_FLOOR) / 2, z))
    iron.build(collection)
    metal = Piece("Metal", palette.METAL)
    for k in range(4):
        metal.add(cylinder(0.25, 3.3, 8), at(0, belt_top - 0.45, belt_back + 0.5 + k * (belt_len - 1) / 3, roll=-90))
    metal.build(collection)

    # A log on the table, just reaching the saw, and one riding on the belt.
    logs = Piece("Log", palette.WOOD)
    rings = Piece("Rings", palette.INNER_WOOD)
    _log(logs, rings, 3.4, 1.8, 0, TABLE_TOP + 1.2, blade_z + SAW / 2 + 1.2, False, rng)
    _log(logs, rings, 2.6, 1.4, 0, belt_top + 0.7, belt_z, False, rng)
    logs.build(collection)
    rings.build(collection)


def saw_blade(collection):
    """Its origin is the middle of the blade, which turns around X."""
    _pivot(collection)
    Piece("Blade", palette.METAL).add(cylinder(SAW / 2, 0.25, 24), at(0, 0, 0, roll=-90)).build(collection)
    teeth = Piece("Teeth", palette.METAL)
    for k in range(1, 13):
        m = Matrix.Rotation(k * math.pi / 6, 4, "X") @ Matrix.Translation((0, 0, SAW / 2)) @ Matrix.Rotation(math.pi / 4, 4, "X")
        teeth.add(rbox((0.25, 0.6, 0.6)), m)
    teeth.build(collection)
    hub = Piece("Hub", palette.DARK_METAL)
    hub.add(cylinder(0.6, 0.6, 10), at(0, 0, 0, roll=-90))
    hub.add(cylinder(0.25, 0.9, 6), at(0, 0, 0, roll=-90))
    hub.build(collection)


def water_wheel(collection):
    """Its origin is the middle of the wheel, which turns around X. The shaft goes into the
    sawmill's wall at -X."""
    _pivot(collection)
    r, width = WHEEL_RADIUS, WHEEL_WIDTH
    step = 2 * math.pi / WHEEL_PIECES
    rim_len = 2 * r * math.tan(step / 2) + 0.2
    rim = Piece("Rim", palette.WOOD)
    paddle = Piece("Paddle", palette.WOOD)
    for k in range(WHEEL_PIECES):
        for sx in (-1, 1):
            rim.add(rbox((0.3, 0.5, rim_len), bevel=0.06), spin(k * step, sx * width / 2, r, 0))
        paddle.add(rbox((width, 1.4, 0.25), bevel=0.04), spin(k * step + step / 2, 0, r - 0.5, 0))
        paddle.add(rbox((width + 0.4, 0.2, 0.2)), spin(k * step + step / 2, 0, r - 1.0, 0.2))
    rim.build(collection)
    paddle.build(collection)
    spoke = Piece("Spoke", palette.DARK_WOOD)
    for k in range(3):
        for sx in (-1, 1):
            spoke.add(rbox((0.3, r * 2 - 0.4, 0.4), bevel=0.05), spin(k * math.pi / 3, sx * width / 2, 0, 0))
    spoke.build(collection)
    Piece("Hub", palette.DARK_WOOD).add(cylinder(0.6, width + 0.4, 10), at(0, 0, 0, roll=-90)).build(collection)
    Piece("Shaft", palette.DARK_METAL).add(cylinder(0.3, 2.6, 8), at(-width / 2 - 1.1, 0, 0, roll=-90)).build(collection)


def workshop(collection):
    """In the sawmill's frame: two sawhorses with a plank by the left wall, a stack of cut
    boards by the right wall and a hand saw on the back wall."""
    w, d = MILL_W, MILL_D
    _pivot(collection)
    wood = Piece("Wood", palette.DARK_WOOD)
    board = Piece("Board", palette.INNER_WOOD)
    x = -w / 2 + 3.5
    for z in (-2.5, 1.5):
        for sx in (-1, 1):
            for sz in (-1, 1):
                wood.add(rbox((0.3, 2.6, 0.3)), at(x + sx * 0.6, MILL_FLOOR + 1.2, z + sz * 0.3, roll=sx * 15))
        wood.add(rbox((1.8, 0.3, 0.6), bevel=0.04), at(x, MILL_FLOOR + 2.45, z))
    board.add(rbox((1.4, 0.3, 6.0), bevel=0.04), at(x, MILL_FLOOR + 2.75, -0.5))
    stack_x = w / 2 - 3
    for k in range(5):
        board.add(rbox((2.4, 0.35, 6.0), bevel=0.04), at(stack_x, MILL_FLOOR + 0.2 + k * 0.37, -1, turn=(k % 2) * 4 - 2))
    back_z = -d / 2 + WALL + 0.1
    metal = Piece("Metal", palette.METAL)
    metal.add(rbox((3.0, 1.0, 0.08), taper=1.0), at(5, 6, back_z))
    for k in range(10):
        metal.add(rbox((0.2, 0.2, 0.06)), at(3.7 + k * 0.28, 5.45, back_z, roll=45))
    wood.add(rbox((1.0, 1.2, 0.2), bevel=0.06), at(6.9, 6.1, back_z))
    wood.add(rbox((0.15, 0.15, 0.3)), at(5, 6.6, back_z + 0.05))  # the nail it hangs on
    wood.build(collection)
    board.build(collection)
    metal.build(collection)


def log_pile(collection):
    """Its origin is the ground under the middle of the pile: logs along Z in rows of 3, 2
    and 1, between two stakes."""
    rng = random.Random(714)
    _pivot(collection)
    logs = Piece("Log", palette.WOOD)
    rings = Piece("Rings", palette.INNER_WOOD)
    for row, count in enumerate((3, 2, 1)):
        for index in range(count):
            offset = (index - (count - 1) / 2) * 1.8
            _log(logs, rings, 6.0 - rng.uniform(0, 0.3), 1.7, offset, 0.85 + row * 1.5, rng.uniform(-0.15, 0.15), False, rng)
    logs.build(collection)
    rings.build(collection)
    wood = Piece("Wood", palette.DARK_WOOD)
    for sx in (-1, 1):
        wood.add(rbox((0.4, 3.6, 0.4), bevel=0.05, taper=0.8), at(sx * 3, 1.8, 0))
    wood.build(collection)
