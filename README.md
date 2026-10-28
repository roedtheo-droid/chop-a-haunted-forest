# Chop a Haunted Forest

A co-op Roblox game: chop every tree in a haunted forest, and watch out for mimics.
The full design is in [GAME_DESIGN.md](GAME_DESIGN.md). Rules for working on it are in [CLAUDE.md](CLAUDE.md).

## How the code is laid out

| Folder         | Shows up in Studio as                        | What goes there                         |
| -------------- | -------------------------------------------- | --------------------------------------- |
| `src/shared/`  | `ReplicatedStorage > Shared`                 | Config, Types, the Remotes list         |
| `src/server/`  | `ServerScriptService > Server` (a Script)    | Server bootstrap + `Systems/` modules   |
| `src/client/`  | `StarterPlayerScripts > Client` (a LocalScript) | Client bootstrap + `Controllers/` modules |

`default.project.json` is the map Rojo uses to put each folder in the right place.

## One-time setup (Windows)

You only do this once per PC.

1. **Install Git:** download it from https://git-scm.com/download/win and click through the installer with the default options.
2. **Get the project:** open PowerShell and run:
   ```
   cd Documents
   git clone https://github.com/roedtheo-droid/chop-a-haunted-forest.git
   cd chop-a-haunted-forest
   ```
3. **Download Rojo into the project folder** (paste one line at a time):
   ```
   $u = "https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-windows-x86_64.zip"
   Invoke-WebRequest $u -OutFile rojo.zip
   Expand-Archive rojo.zip . -Force
   ```
   This puts `rojo.exe` next to the code. Git ignores it, so it never gets uploaded.
4. **Install the Rojo plugin in Studio:** close Roblox Studio, then run `.\rojo.exe plugin install`.

## Every time you work on the game

1. Open PowerShell in the project folder (`cd Documents\chop-a-haunted-forest`) and run: `.\rojo.exe serve`
   Leave this window open. It says `Rojo server listening` when it's ready.
2. Open Roblox Studio and open your place (or make a new **Baseplate**).
3. Go to the **Plugins** tab and click **Rojo**. A small Rojo window opens.
4. Click **Connect**. Studio now has the code from `src/`, and it updates live when the files change.
5. To get the newest code from GitHub, run `git pull` in the project folder (Rojo picks up the change by itself).

Tip: Rojo copies code *into* Studio. If you edit a script inside Studio, Rojo will overwrite it. Always change the files in `src/` instead.

## Blender models

The trees, rocks, ground, the forest's edges, the view outside and (later) everything else
are 3D models made by Python scripts in the `blender/` folder. The finished files are already
in `blender/export/` (`.fbx`), with a picture of each one in `blender/previews/`. Rojo can't
copy models into Studio, so you import them yourself, **once**. Until you do, the game
simply builds the old blocky version.

**Import all the models at once** (the easy way):

1. In Studio, open the **File** menu and click **Import 3D**. Pick `blender/export/AllModels.fbx`: every model in one file.
2. In the import window, keep the settings as they are and click **Import**. (Don't worry about the size: the game resizes every model itself. If there's a "Merge meshes" option, leave it off: the game needs the parts separate.)
3. A model called `AllModels` shows up in the Workspace. In the Explorer, find **ServerStorage**. The first time, add a **Folder** in it and name it `MapAssets`.
4. Drag `AllModels` into `ServerStorage > MapAssets`.
5. Save the place (File > Save). The models live in the place file, not in GitHub.

When the models change (a new step adds some), delete the old `AllModels` in `MapAssets` and import the new one.

**Or one model at a time:** import its own file (for example `Oak.fbx`) the same way and drag it into
`MapAssets`. Its name must match the file name. A model on its own wins over the same model in
`AllModels`. The models so far:
- trees and rocks: `Oak`, `Pine`, `Birch`, `BarkBlock`, `Rock1`, `Rock2`
- ground and river: `Patch1`, `Patch2`, `Patch3`, `Pebbles`, `RiverBank`
- edges and gates: `Hedge1`, `Hedge2`, `Hedge3`, `RidgeRock1`, `RidgeRock2`, `StoneWall1`, `StoneWall2`, `LogGatehouse`, `StoneGatehouse`
- outside: `Mountains1`, `Mountains2`, `Hill1`, `Hill2`

When you press Play, the Output window says which models the game found
(`[Assets] Using the Blender model "Oak"`) and which ones are missing.

**Rebuild the models** (only needed after changing the scripts in `blender/`). With Blender installed:

```
blender --background --python blender/build.py -- all bundle
```

or with Blender's Python package instead (`pip install bpy`, needs Python 3.13): `python blender/build.py all bundle`.
(`pilot`, `ground`, `edges` or `outside` instead of `all` builds just those models; `bundle` makes `AllModels.fbx`.)

Then import the changed files again (delete the old copy in `MapAssets` first).

## Game settings to set once in Studio

- **Max players = 4:** Home tab > Game Settings > Places > (your place) > Max Players. You must publish the game first for this option to appear.
