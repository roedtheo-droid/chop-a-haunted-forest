# Chop a Haunted Forest

A co-op Roblox game: chop every tree in a haunted forest, and watch out for mimics.
The full design is in [GAME_DESIGN.md](GAME_DESIGN.md). Rules for working on it are in [CLAUDE.md](CLAUDE.md).

## How the code is laid out

| Folder         | Lives in Studio as                           | What goes there                         |
| -------------- | -------------------------------------------- | --------------------------------------- |
| `src/shared/`  | `ReplicatedStorage > Shared`                 | Config, Types, the Remotes list         |
| `src/server/`  | `ServerScriptService > Server` (a Script)    | Server bootstrap + `Build/` and `Systems/` modules |
| `src/client/`  | `StarterPlayerScripts > Client` (a LocalScript) | Client bootstrap + `Controllers/` modules |

`init.server.luau` is the `Server` Script itself and `init.client.luau` is the `Client` LocalScript.
Every other file is a ModuleScript with the same name, in the same folder.

## Studio and GitHub (no Rojo)

We don't use Rojo any more. The game in **Roblox Studio is the real copy** of the code, and
GitHub keeps a copy of every script plus the history of every change.

**Every time you work on the game**

1. Open your place in Roblox Studio.
2. Change scripts right in Studio (you, or Claude with its Studio tools).
3. Save the place: **File > Save** (or **Publish to Roblox**). The code lives in the place file now,
   so an unsaved change is a lost change.

**After each step** Claude copies the scripts from Studio into `src/`, puts them on a branch,
opens a pull request and merges it once you say ok. You don't need to run git yourself.

**How Claude checks that Studio and `src/` match**

1. Run `tools/studio_hashes.luau` in Studio (Command Bar or Claude's `execute_luau`) and save
   what it prints to a file, for example `studio.txt`.
2. Run `python tools/repo_hashes.py studio.txt`. It lists every script that is different, only in
   Studio, or only in `src/`.
3. Copy each listed script's Source from Studio into its file in `src/`. A new ModuleScript in
   `ServerScriptService > Server > Systems` becomes `src/server/Systems/<Name>.luau`, and so on.
4. Run the check again until it says `Studio and src/ match.`, then commit.

`default.project.json` is kept as the map of which folder goes where. It also means you could go
back to Rojo any day without changing anything else.

## Blender models

The trees, rocks, ground, the forest's edges, the view outside and (later) everything else
are 3D models made by Python scripts in the `blender/` folder. The finished files are already
in `blender/export/` (`.fbx`), with a picture of each one in `blender/previews/`. Models aren't
scripts, so you import them into Studio yourself, **once**. Until you do, the game
simply builds the old blocky version.

**Import all the models at once** (the easy way):

1. In Studio, open the **File** menu and click **Import** (in some versions **Import 3D**). Pick `blender/export/AllModels.fbx`: every model in one file.
2. In the import window, keep the settings as they are and click **Import**. (Don't worry about the size: the game resizes every model itself. If there's a "Merge meshes" option, leave it off: the game needs the parts separate.)
3. A model called `AllModels` shows up in the Workspace. In the Explorer, find **ServerStorage**. The first time, add a **Folder** in it and name it `MapAssets`.
4. Drag `AllModels` into `ServerStorage > MapAssets`.
5. Save the place (File > Save). The models live in the place file, not in GitHub.

When the models change (a new step adds some), delete the old `AllModels` in `MapAssets` and import the new one.

**Or one model at a time:** import its own file (for example `Oak.fbx`) the same way and drag it into
`MapAssets`. Its name must match the file name. A model on its own wins over the same model in
`AllModels`. The models so far:
- trees and rocks: `Oak`, `Pine`, `Birch`, `BarkBlock`, `Rock1`, `Rock2`
- more trees: `Oak2`, `Pine2`, `Birch2`, `Willow1`, `Willow2`, `DeadOak1`, `DeadOak2`
- ground and river: `Patch1`, `Patch2`, `Patch3`, `Pebbles`, `RiverBank`
- edges and gates: `Hedge1`, `Hedge2`, `Hedge3`, `RidgeRock1`, `RidgeRock2`, `StoneWall1`, `StoneWall2`, `LogGatehouse`, `StoneGatehouse`
- outside: `Mountains1`, `Mountains2`, `Hill1`, `Hill2`
- props: `BerryBush`, `FallenLog`, `LampPost`, `FenceSection`, `Pumpkin`, `Gravestone1`, `Gravestone2`, `Gravestone3`, `Reeds`, `LilyPad`
- ground details: `GrassTuft`, `Flowers`, `Fern`, `Mushrooms`, `DeadLeaves`, `Bones`
- landmarks: `Tent`, `Dock`, `Rowboat`, `WindmillTower`, `WindmillSails`, `IronFence`, `Crypt`, `BossStone1`, `BossStone2`
- camp: `Bridge`, `Well`, `QuestBoard`, `Campfire`, `Bench`, `Signpost`, `SignArrow`
- logs and the boss: `Log`, `Stump`, `ElderTrunk`, `ElderCrown`, `ElderRoot`
- the Tool Shed: `ToolShedShell`, `Barrel`, `Crate`, `HangingLamp` (the `Stove`, `Armchair` and `UpgradeBench` models aren't used since the shop got its wall boards)
- the sawmills: `SawmillShed`, `SawTable`, `SawBlade`, `WaterWheel`, `Workshop`, `LogPile`

When you press Play, the Output window says which models the game found
(`[Assets] Using the Blender model "Oak"`) and which ones are missing.

**Rebuild the models** (only needed after changing the scripts in `blender/`). With Blender installed:

```
blender --background --python blender/build.py -- all bundle
```

or with Blender's Python package instead (`pip install bpy`, needs Python 3.13): `python blender/build.py all bundle`.
(`pilot`, `trees`, `ground`, `edges`, `outside`, `props`, `details`, `landmarks`, `camp`, `logs` or `buildings` instead of `all` builds just those models;
`bundle` makes `AllModels.fbx`.)

Then import the changed files again (delete the old copy in `MapAssets` first).

## Game settings to set once in Studio

- **Max players = 4:** Home tab > Game Settings > Places > (your place) > Max Players. You must publish the game first for this option to appear.
