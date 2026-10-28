"""Builds the game's Blender models: an .fbx file for Roblox Studio and a preview picture each.

Run it from the project folder, either with Blender's Python package (pip install bpy):
    python blender/build.py pilot
or with Blender itself:
    blender --background --python blender/build.py -- pilot

Kits (what to build):
    pilot   the first test models: Oak, Pine, Birch, BarkBlock, Rock1, Rock2
    ground  ground patches, pebbles and river banks: Patch1-3, Pebbles, RiverBank
    trees   more tree shapes: Oak2, Pine2, Birch2, Willow1-2, DeadOak1-2
    edges   the forest's edges: Hedge1-3, RidgeRock1-2, StoneWall1-2, LogGatehouse, StoneGatehouse
    outside the view outside the forest: Mountains1-2, Hill1-2
    all     every model
You can also name single models: python blender/build.py Oak Rock2
And "bundle" packs every model into one file, blender/export/AllModels.fbx, so Studio needs
only one import: python blender/build.py bundle

Files go to blender/export/<Name>.fbx and blender/previews/<Name>.png.
How to get them into the game: see "Blender models" in README.md.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from lib import output  # noqa: E402
from mathutils import Vector  # noqa: E402
from models import edges, ground, outside, rocks, trees  # noqa: E402

MODELS = {
    "Oak": trees.oak,
    "Pine": trees.pine,
    "Birch": trees.birch,
    "BarkBlock": trees.bark_block,
    "Oak2": trees.oak2,
    "Pine2": trees.pine2,
    "Birch2": trees.birch2,
    "Willow1": trees.willow1,
    "Willow2": trees.willow2,
    "DeadOak1": trees.dead_oak1,
    "DeadOak2": trees.dead_oak2,
    "Rock1": rocks.rock1,
    "Rock2": rocks.rock2,
    "Patch1": ground.patch1,
    "Patch2": ground.patch2,
    "Patch3": ground.patch3,
    "Pebbles": ground.pebbles,
    "RiverBank": ground.river_bank,
    "Hedge1": edges.hedge1,
    "Hedge2": edges.hedge2,
    "Hedge3": edges.hedge3,
    "RidgeRock1": edges.ridge_rock1,
    "RidgeRock2": edges.ridge_rock2,
    "StoneWall1": edges.stone_wall1,
    "StoneWall2": edges.stone_wall2,
    "LogGatehouse": edges.log_gatehouse,
    "StoneGatehouse": edges.stone_gatehouse,
    "Mountains1": outside.mountains1,
    "Mountains2": outside.mountains2,
    "Hill1": outside.hill1,
    "Hill2": outside.hill2,
}

KITS = {
    "pilot": ["Oak", "Pine", "Birch", "BarkBlock", "Rock1", "Rock2"],
    "trees": ["Oak2", "Pine2", "Birch2", "Willow1", "Willow2", "DeadOak1", "DeadOak2"],
    "ground": ["Patch1", "Patch2", "Patch3", "Pebbles", "RiverBank"],
    "edges": [
        "Hedge1",
        "Hedge2",
        "Hedge3",
        "RidgeRock1",
        "RidgeRock2",
        "StoneWall1",
        "StoneWall2",
        "LogGatehouse",
        "StoneGatehouse",
    ],
    "outside": ["Mountains1", "Mountains2", "Hill1", "Hill2"],
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


def bundle(names, gap=8):
    """Every model in one file, blender/export/AllModels.fbx, side by side along X. Each part
    is named "<Model>__<Part>" ("Oak__Trunk"), so the game can tell which model it belongs to
    (see src/server/Build/Assets.luau)."""
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
            # Renamed right away, so the next model's "Trunk" doesn't become "Trunk.001".
            obj.name = f"{name}__{obj.name}"
            obj.data.name = obj.name
        x += max(xs) - min(xs) + gap
    print(f"[build] All models: {output.export_fbx('AllModels')}")


def main(args):
    names = []
    kits = []
    for arg in args or ["pilot"]:
        if arg == "bundle":
            bundle(list(MODELS))
            continue
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
