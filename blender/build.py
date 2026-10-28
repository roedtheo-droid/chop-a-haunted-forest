"""Builds the game's Blender models: an .fbx file for Roblox Studio and a preview picture each.

Run it from the project folder, either with Blender's Python package (pip install bpy):
    python blender/build.py pilot
or with Blender itself:
    blender --background --python blender/build.py -- pilot

Kits (what to build):
    pilot   the first test models: Oak, Pine, Birch, BarkBlock, Rock1, Rock2
    all     every model
You can also name single models: python blender/build.py Oak Rock2

Files go to blender/export/<Name>.fbx and blender/previews/<Name>.png.
How to get them into the game: see "Blender models" in README.md.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from lib import output  # noqa: E402
from mathutils import Vector  # noqa: E402
from models import rocks, trees  # noqa: E402

MODELS = {
    "Oak": trees.oak,
    "Pine": trees.pine,
    "Birch": trees.birch,
    "BarkBlock": trees.bark_block,
    "Rock1": rocks.rock1,
    "Rock2": rocks.rock2,
}

KITS = {
    "pilot": ["Oak", "Pine", "Birch", "BarkBlock", "Rock1", "Rock2"],
}
KITS["all"] = list(MODELS)


def build(name, preview=True):
    collection = output.fresh_scene()
    MODELS[name](collection)
    path = output.export_fbx(name)
    print(f"[build] {name}: {path}")
    if preview:
        print(f"[build] {name}: {output.render_preview(name)}")


def lineup(kit, names, gap=4):
    """One picture of a whole kit side by side: blender/previews/Kit_<kit>.png."""
    collection = output.fresh_scene()
    x = 0
    for name in names:
        before = set(bpy.context.scene.objects)
        MODELS[name](collection)
        bpy.context.view_layer.update()
        new = [obj for obj in bpy.context.scene.objects if obj not in before]
        xs = [(obj.matrix_world @ Vector(corner)).x for obj in new for corner in obj.bound_box]
        shift = x - min(xs)
        for obj in new:
            obj.location.x += shift
        x += max(xs) - min(xs) + gap
    print(f"[build] Kit {kit}: {output.render_preview(f'Kit_{kit}', size=1600, height=700, samples=64)}")


def main(args):
    names = []
    kits = []
    for arg in args or ["pilot"]:
        if arg in KITS:
            names.extend(KITS[arg])
            kits.append(arg)
        elif arg in MODELS:
            names.append(arg)
        else:
            raise SystemExit(f"Unknown kit or model: {arg}. Kits: {', '.join(KITS)}. Models: {', '.join(MODELS)}")
    for name in dict.fromkeys(names):
        build(name)
    for kit in kits:
        lineup(kit, KITS[kit])


if __name__ == "__main__":
    # When Blender runs this script, our arguments come after "--".
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    main([a for a in argv if not a.startswith("-")])
