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
2. **Install Aftman** (it installs Rojo at the exact version this project uses):
   1. Go to https://github.com/LPGhatguy/aftman/releases and download the `windows-x86_64` zip from the latest release.
   2. Unzip it. Open a terminal (PowerShell) in that folder and run: `.\aftman.exe self-install`
   3. Close the terminal and open a new one.
3. **Get the project:** in a new terminal, go to where you want the project and clone it:
   ```
   cd Documents
   git clone https://github.com/<your-name>/chop-a-haunted-forest.git
   cd chop-a-haunted-forest
   ```
4. **Install Rojo:** in the project folder run `aftman install`. Type `y` if it asks whether to trust `rojo`.
5. **Install the Rojo plugin in Studio:** close Roblox Studio, then run `rojo plugin install`.

## Every time you work on the game

1. Open a terminal in the project folder and run: `rojo serve`
   Leave this window open. It says `Rojo server listening` when it's ready.
2. Open Roblox Studio and open your place (or make a new **Baseplate**).
3. Go to the **Plugins** tab and click **Rojo**. A small Rojo window opens.
4. Click **Connect**. Studio now has the code from `src/`, and it updates live when the files change.
5. To get the newest code from GitHub, run `git pull` in the project folder (Rojo picks up the change by itself).

Tip: Rojo copies code *into* Studio. If you edit a script inside Studio, Rojo will overwrite it. Always change the files in `src/` instead.

## Game settings to set once in Studio

- **Max players = 4:** Home tab > Game Settings > Places > (your place) > Max Players. You must publish the game first for this option to appear.
