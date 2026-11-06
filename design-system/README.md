# 3D Roblox tools modeling

A small React library for building the game's 3D models. Its pieces (`Block`, `Tooth`, `Chain`...) are
uploaded to the Claude Design project
[3D Roblox tools modeling](https://claude.ai/design/p/3fe88102-c49b-4f54-b131-08ee58ce261e), so Claude
Design's agent can build models with them and show them live.

The game itself doesn't use this code. What reaches the game is a `.gltf` file in `../models`, which you
import into Studio once.

## Commands

Run these from this folder, with Node installed.

```bash
npm install
```

```bash
npm run build
```

Writes the finished models to `../models`:

```bash
npm run export-models
```

Takes pictures of a model in a real browser (the list holds one set of props per view):

```bash
node tools/picture.mjs Gnawbert out.png "[{\"yaw\":25,\"mouth\":0.8}]"
```

## Adding a model

1. Add `src/models/<Name>.tsx`, a plain function with no hooks, and export it from `src/index.ts`.
2. Add `docs/<Name>.md` and `.design-sync/previews/<Name>.tsx`.
3. Add its name to `MODELS` in `tools/export-gltf.mjs`.

Claude runs the sync to Claude Design with `/design-sync`. Its settings and notes are in `.design-sync/`.
