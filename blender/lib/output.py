"""Saving models: a fresh scene for each one, the FBX file Roblox Studio imports, and a
preview picture (so we can see a model without opening Blender or Studio)."""

import math
import os

import bpy
from mathutils import Vector

from . import geometry

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXPORT_DIR = os.path.join(ROOT, "export")
PREVIEW_DIR = os.path.join(ROOT, "previews")


def fresh_scene():
    """An empty scene to build one model in."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    geometry._materials.clear()
    return bpy.context.scene.collection


def export_fbx(name):
    """Save every mesh in the scene as blender/export/<name>.fbx.
    Y is up and transforms are baked, so in Studio every part comes in standing upright and
    unturned (the game relies on a tree's Trunk not being turned)."""
    os.makedirs(EXPORT_DIR, exist_ok=True)
    path = os.path.join(EXPORT_DIR, f"{name}.fbx")
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=False,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        bake_space_transform=True,
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="STRIP",
    )
    return path


def _bounds():
    low = Vector((math.inf,) * 3)
    high = Vector((-math.inf,) * 3)
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            low = Vector(map(min, low, world))
            high = Vector(map(max, high, world))
    return low, high


def render_preview(name, size=640, height=None, samples=48, sky=(0.62, 0.78, 0.92)):
    """Render blender/previews/<name>.png: the model on a grass disc under a sunny sky,
    seen from the front and a little above, like a player standing near it."""
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene = bpy.context.scene
    bpy.context.view_layer.update()
    low, high = _bounds()
    middle = (low + high) / 2
    extent = max(high.x - low.x, high.y - low.y, high.z - low.z)

    # Ground: a big flat grass disc just under the model (a hair lower, so a model's flat
    # bottom, like a hill's sunk edge, doesn't flicker against it).
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=extent * 3, depth=0.1, location=(middle.x, middle.y, low.z - 0.1))
    ground = bpy.context.active_object
    ground.data.materials.append(geometry.material((0.42, 0.68, 0.30)))

    # Camera: in front (-Y), a little to the side and above.
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.lens = 50
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    distance = extent * 2.4
    cam_data.clip_end = distance * 3  # big models (mountains) are further away than Blender's default
    direction = Vector((math.sin(math.radians(28)), -math.cos(math.radians(28)), 0.42)).normalized()
    cam.location = middle + direction * distance
    look = (middle - cam.location).normalized()
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    # Light: a warm sun from the upper left, and a soft sky.
    sun_data = bpy.data.lights.new("Sun", type="SUN")
    sun_data.energy = 3.2
    sun_data.angle = math.radians(8)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(50), math.radians(-25), math.radians(-35))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("Sky")
    if not world.node_tree:
        world.use_nodes = True  # older Blenders; Blender 5 always uses nodes
    background = world.node_tree.nodes.get("Background")
    if background:
        background.inputs["Color"].default_value = (*geometry.srgb_to_linear(sky), 1.0)
        background.inputs["Strength"].default_value = 0.9
    scene.world = world

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.render.resolution_x = size
    scene.render.resolution_y = height or size
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    path = os.path.join(PREVIEW_DIR, f"{name}.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path
