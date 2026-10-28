"""Chunky low-poly shapes for the game's models (see STYLE_GUIDE.md).

Everything is built from boxes: a box can be bevelled (soft, chamfered edges that catch the
light), tapered (a smaller top, for pine tiers) and jittered (wobbly corners, for rocks).
Several boxes ("islands") are merged into one object, and each object gets ONE colour in the
game, so every colour slot of a model is its own object, named the way the game expects
("Trunk", "Leaves", "LeafBlock_1", "Root_2"...).

Units are studs. Blender's Z axis is up; the FBX export turns that into Roblox's Y.
"""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

UV_STUDS = 8  # one tile of a Roblox material (Wood, Slate...) covers this many studs


def box(size, bevel=0.0, taper=1.0, jitter=0.0, rng=None):
    """A box of `size` (x, y, z) centred on the origin, as a new bmesh.

    bevel  chamfers every edge by this many studs
    taper  the top face is this much smaller than the bottom (1 = a plain box)
    jitter moves every corner up to this many studs, for rough rocks
    """
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.x *= taper
            v.co.y *= taper
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if bevel > 0:
        bmesh.ops.bevel(
            bm,
            geom=list(bm.verts) + list(bm.edges),
            offset=bevel,
            offset_type="OFFSET",
            segments=1,
            profile=0.5,
            affect="EDGES",
            clamp_overlap=True,
        )
    if jitter > 0:
        rng = rng or random.Random(1)
        for v in bm.verts:
            v.co += Vector((rng.uniform(-jitter, jitter), rng.uniform(-jitter, jitter), rng.uniform(-jitter, jitter)))
    return bm


def wedge(size, bevel=0.0):
    """A ramp of `size` (x, y, z): full height at -Y, sloping down to the ground at +Y.
    Its bottom sits at z = 0 (not centred), so roots and ramps stand on the ground."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        if v.co.z > 0 and v.co.y > 0:
            v.co.z = -0.5  # the far top edge drops to the ground
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z = (v.co.z + 0.5) * size[2]
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
    if bevel > 0:
        bmesh.ops.bevel(
            bm,
            geom=list(bm.verts) + list(bm.edges),
            offset=bevel,
            offset_type="OFFSET",
            segments=1,
            profile=0.5,
            affect="EDGES",
            clamp_overlap=True,
        )
    return bm


def cap(source, min_up=0.85, lift=0.05, thickness=0.14):
    """A thin layer copied from the upward-facing faces of `source` (a bmesh, not changed),
    lifted a hair above them: moss or snow that follows the shape exactly."""
    bm = source.copy()
    bm.normal_update()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z < min_up], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for v in bm.verts:
        v.co.z += lift
    extruded = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
    for item in extruded["geom"]:
        if isinstance(item, bmesh.types.BMVert):
            item.co.z -= thickness
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def blob(radius_x, radius_y, thickness, sides=12, jitter=0.15, waist=0.0, rng=None):
    """A flat, irregular patch: a jagged oval `radius_x` by `radius_y`, `thickness` thick,
    centred on the origin. `waist` pinches its middle (0.45 makes a peanut shape)."""
    rng = rng or random.Random(7)
    bm = bmesh.new()
    ring = []
    for i in range(sides):
        a = (i + rng.uniform(-0.25, 0.25)) / sides * 2 * math.pi
        r = 1 + rng.uniform(-jitter, jitter)
        pinch = 1 - waist * (1 - abs(math.cos(a)))
        ring.append(bm.verts.new((math.cos(a) * radius_x * r, math.sin(a) * radius_y * r * pinch, -thickness / 2)))
    bottom = bm.faces.new(ring)
    extruded = bmesh.ops.extrude_face_region(bm, geom=[bottom])
    for item in extruded["geom"]:
        if isinstance(item, bmesh.types.BMVert):
            item.co.z += thickness
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def ridge(length, profile, sections=4, wobble=0.0, rise_jitter=0.0, rng=None):
    """A long strip along X whose cross-section is `profile`: a closed list of (y, z) points
    (z = 0 is the ground). Like a river bank. Each section is nudged and raised a little at
    random, so it doesn't look machine-made."""
    rng = rng or random.Random(9)
    bm = bmesh.new()
    rows = []
    for i in range(sections + 1):
        x = -length / 2 + length * i / sections
        end = i in (0, sections)
        dy = 0 if end else rng.uniform(-wobble, wobble)
        lift = 1 + rng.uniform(-rise_jitter, rise_jitter)
        rows.append([bm.verts.new((x, y + dy, z * lift)) for (y, z) in profile])
    count = len(profile)
    for i in range(sections):
        for j in range(count):
            k = (j + 1) % count
            bm.faces.new((rows[i][j], rows[i][k], rows[i + 1][k], rows[i + 1][j]))
    bm.faces.new(rows[0])
    bm.faces.new(list(reversed(rows[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def peak(radius, height, sides=5, jitter=0.15, lean=(0.0, 0.0), snow=0.0, rng=None):
    """A chunky mountain peak standing on z = 0: a jagged base with `sides` corners, a jagged
    ring part way up (turned half a step, so the slopes break into many facets) and a point at
    the top, moved sideways by `lean` (a share of the radius).
    Returns (rock, cap): with `snow` (the share of the height, from the top, that's white) the
    cap is a snow layer over the faces above the snowline, a hair outside them; else None."""
    rng = rng or random.Random(5)
    bm = bmesh.new()
    turn = rng.uniform(0, 2 * math.pi)
    apex = Vector((lean[0] * radius, lean[1] * radius, height))
    mid_z = height * rng.uniform(0.42, 0.55)
    share = mid_z / height
    base, mid = [], []
    for i in range(sides):
        a = turn + (i + rng.uniform(-0.2, 0.2)) / sides * 2 * math.pi
        r = radius * (1 + rng.uniform(-jitter, jitter))
        base.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0)))
    for i in range(sides):
        a = turn + (i + 0.5 + rng.uniform(-0.15, 0.15)) / sides * 2 * math.pi
        r = radius * (1 - share) * rng.uniform(0.95, 1.2)
        centre = apex * share
        mid.append(bm.verts.new((centre.x + math.cos(a) * r, centre.y + math.sin(a) * r, mid_z + rng.uniform(-0.05, 0.05) * height)))
    top = bm.verts.new(apex)
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((base[i], base[j], mid[i]))
        bm.faces.new((mid[i], base[j], mid[j]))
        bm.faces.new((mid[i], mid[j], top))
    bm.faces.new(list(reversed(base)))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))

    if snow <= 0:
        return bm, None
    # The snowline crosses each edge from the ring to the top at a slightly different height,
    # so it's jagged. Its points lie on the mountain's faces, so the cap is then grown a little
    # around a point inside the peak, to sit just outside them.
    line = max(height * (1 - snow), mid_z + 0.05 * height)
    ring = []
    for vert in mid:
        z = line + rng.uniform(-0.06, 0.06) * height
        u = min(max((z - vert.co.z) / (height - vert.co.z), 0.05), 0.9)
        ring.append(vert.co.lerp(apex, u))
    centre = (sum(ring, Vector()) / len(ring) + apex) / 2
    cap_bm = bmesh.new()
    cap_ring = [cap_bm.verts.new(centre + (point - centre) * 1.025) for point in ring]
    cap_top = cap_bm.verts.new(centre + (apex - centre) * 1.025)
    for i in range(sides):
        cap_bm.faces.new((cap_ring[i], cap_ring[(i + 1) % sides], cap_top))
    cap_bm.faces.new(list(reversed(cap_ring)))
    bmesh.ops.recalc_face_normals(cap_bm, faces=list(cap_bm.faces))
    return bm, cap_bm


def terrain(width, depth, height_at, columns=12, rows=7, wobble=0.25, sink=0.6, rng=None):
    """A bumpy sheet of ground `width` by `depth`, centred on the origin: its height at (x, y)
    is height_at(x, y), minus `sink`, so where that is 0 it's under the ground and the hill's
    edge is wherever it comes up. The corners are nudged a little (`wobble`, a share of a
    cell), and the cells are split into triangles the two ways in turn, so it looks faceted."""
    rng = rng or random.Random(11)
    bm = bmesh.new()
    grid = []
    for r in range(rows + 1):
        line = []
        for c in range(columns + 1):
            x = -width / 2 + width * c / columns
            y = -depth / 2 + depth * r / rows
            if 0 < c < columns and 0 < r < rows:
                x += rng.uniform(-wobble, wobble) * width / columns
                y += rng.uniform(-wobble, wobble) * depth / rows
            line.append(bm.verts.new((x, y, height_at(x, y) - sink)))
        grid.append(line)
    for r in range(rows):
        for c in range(columns):
            a, b, cc, d = grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]
            # Corners in counter-clockwise order seen from above, so every face points up.
            if (r + c) % 2 == 0:
                bm.faces.new((a, b, cc))
                bm.faces.new((a, cc, d))
            else:
                bm.faces.new((a, b, d))
                bm.faces.new((b, cc, d))
    bm.normal_update()
    return bm


def place(location=(0, 0, 0), turn_z=0.0, tilt_x=0.0, tilt_y=0.0, orbit_z=0.0):
    """A matrix that tilts (degrees around X and Y), turns (degrees around Z), moves to
    `location`, and then swings around the middle of the model (degrees around Z), like the
    hands of a clock: handy for things spread around a trunk."""
    return (
        Matrix.Rotation(math.radians(orbit_z), 4, "Z")
        @ Matrix.Translation(Vector(location))
        @ Matrix.Rotation(math.radians(turn_z), 4, "Z")
        @ Matrix.Rotation(math.radians(tilt_y), 4, "Y")
        @ Matrix.Rotation(math.radians(tilt_x), 4, "X")
    )


class Piece:
    """One object of a model: several boxes merged together, all one colour in the game."""

    def __init__(self, name, color):
        self.name = name
        self.color = color
        self.bm = bmesh.new()

    def add(self, island, matrix=None):
        if matrix is not None:
            bmesh.ops.transform(island, matrix=matrix, verts=island.verts)
        temp = bpy.data.meshes.new("temp")
        island.to_mesh(temp)
        island.free()
        self.bm.from_mesh(temp)
        bpy.data.meshes.remove(temp)
        return self

    def build(self, collection):
        """Turn the merged boxes into a Blender object, with its origin in the middle of its
        bounding box (Roblox puts a MeshPart's position there too) and box-projected UVs."""
        mesh = bpy.data.meshes.new(self.name)
        box_uvs(self.bm)
        self.bm.normal_update()
        self.bm.to_mesh(mesh)
        self.bm.free()
        coords = [v.co for v in mesh.vertices]
        low = Vector((min(c.x for c in coords), min(c.y for c in coords), min(c.z for c in coords)))
        high = Vector((max(c.x for c in coords), max(c.y for c in coords), max(c.z for c in coords)))
        middle = (low + high) / 2
        mesh.transform(Matrix.Translation(-middle))
        obj = bpy.data.objects.new(self.name, mesh)
        obj.location = middle
        obj.data.materials.append(material(self.color))
        collection.objects.link(obj)
        return obj


def box_uvs(bm):
    """Flat UVs for every face, projected from the side it faces, so Roblox materials
    (Wood, Slate, Grass) show the same size on every face."""
    uv_layer = bm.loops.layers.uv.verify()
    bm.faces.ensure_lookup_table()
    for face in bm.faces:
        n = face.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in face.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                uv = (co.x, co.y)
            elif ax >= ay:
                uv = (co.y, co.z)
            else:
                uv = (co.x, co.z)
            loop[uv_layer].uv = (uv[0] / UV_STUDS, uv[1] / UV_STUDS)


_materials = {}


def material(color):
    """A plain material of one colour (the game recolours parts anyway; this is for previews)."""
    key = tuple(round(c, 4) for c in color)
    if key in _materials and _materials[key].name in bpy.data.materials:
        return _materials[key]
    mat = bpy.data.materials.new(f"Colour_{len(_materials)}")
    if not mat.node_tree:
        mat.use_nodes = True  # older Blenders; Blender 5 always uses nodes
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*srgb_to_linear(color), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.85
    mat.diffuse_color = (*srgb_to_linear(color), 1.0)
    _materials[key] = mat
    return mat


def srgb_to_linear(color):
    def one(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return tuple(one(c) for c in color)


def bark(piece, width, height, depth=None, ridges=3, rng=None):
    """A square trunk with raised bark ridges on all four sides, standing on z = 0.
    Its outside is exactly `width` x `depth` x `height`, so the game can read the trunk's
    size from the part (and cut the chop notch in the right place)."""
    depth = depth or width
    rng = rng or random.Random(3)
    core = 0.86
    piece.add(box((width * core, depth * core, height)), place((0, 0, height / 2)))
    # Corner posts, so the outline is a clean square.
    post = width * 0.13
    for sx in (-1, 1):
        for sy in (-1, 1):
            piece.add(
                box((post, post, height), bevel=post * 0.2),
                place((sx * (width / 2 - post / 2), sy * (depth / 2 - post / 2), height / 2)),
            )
    # Ridges between the corners on every side.
    for side in range(4):
        along = width if side % 2 == 0 else depth
        out = depth if side % 2 == 0 else width
        usable = along - 2 * post
        for i in range(ridges):
            w = usable / ridges * rng.uniform(0.45, 0.7)
            centre = -usable / 2 + usable / ridges * (i + 0.5) + rng.uniform(-0.08, 0.08) * usable / ridges
            thick = out * (1 - core) / 2 + out * 0.02
            ridge = box((w, thick, height), bevel=min(w, thick) * 0.3)
            offset = out / 2 - thick / 2
            if side == 0:
                piece.add(ridge, place((centre, offset, height / 2)))
            elif side == 1:
                piece.add(ridge, place((offset, centre, height / 2), turn_z=90))
            elif side == 2:
                piece.add(ridge, place((centre, -offset, height / 2)))
            else:
                piece.add(ridge, place((-offset, centre, height / 2), turn_z=90))
    return piece


def leaf_clump(piece, size, location, turn=0.0, bumps=4, rng=None):
    """A chunky block of leaves: a bevelled cube with smaller cubes bulging out of its sides
    and top, so the crown looks leafy instead of perfectly square."""
    rng = rng or random.Random(5)
    piece.add(box((size, size, size), bevel=size * 0.12), place(location, turn_z=turn))
    # The top always gets a clump; the sides get the rest, sitting high so they read as
    # more leaves on the crown rather than knobs stuck to its sides.
    sides = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0)]
    rng.shuffle(sides)
    for d in [(0, 0, 1)] + sides[: max(bumps - 1, 0)]:
        s = size * rng.uniform(0.52, 0.64)
        sink = s * 0.28  # how far it sticks out of the main block
        if d[2] == 1:
            offset = Vector((rng.uniform(-0.15, 0.15) * size, rng.uniform(-0.15, 0.15) * size, size / 2 - s / 2 + sink))
        else:
            along = rng.uniform(-0.15, 0.15) * size
            offset = Vector((d[0] * (size / 2 - s / 2 + sink) + abs(d[1]) * along,
                             d[1] * (size / 2 - s / 2 + sink) + abs(d[0]) * along,
                             rng.uniform(0.05, 0.22) * size))
        rotated = Matrix.Rotation(math.radians(turn), 3, "Z") @ offset
        piece.add(
            box((s, s, s * 0.9), bevel=s * 0.16),
            place(Vector(location) + rotated, turn_z=turn + rng.uniform(-18, 18)),
        )
    return piece
