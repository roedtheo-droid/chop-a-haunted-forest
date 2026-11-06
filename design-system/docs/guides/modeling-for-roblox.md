# Modeling for the game

These components build 3D models for the Roblox game Trees With Teeth, and each model is seen live in a `ModelStage`. The look is a spooky storybook: chunky and angular, with muted colours, cartoon scares and no gore.

## The rules of the style

- Everything is built from angular blocks with cut edges. No spheres, and no smooth round trunks.
- Colours come from the palette by name, like `bark`, `bone` or `amber`. Avoid hot pink and loud green.
- Models show their size against a player: a player is about 5.5 studs tall. Turn on `person` on the stage to compare.

## How a model goes together

- Build it facing +Z, standing on y = 0, with its origin at the bottom middle.
- One `ModelPart` per colour, not one per shape. Fewer parts run faster on phones.
- Part names matter, because the game finds parts by name to paint them. Use clear names like `Trunk`, `Teeth` or `Eye`.
- Anything the game moves goes in its own `MovingGroup`, with its hinge where it should turn.
- Keep a whole model under about 8,000 triangles. Each cut edge adds triangles, so small details can use `bevel={0}`.

## From here to the game

A model is a plain function that returns these pieces, with no hooks. Claude Code writes it out as a `.gltf` file, and it gets imported once with File > Import in Roblox Studio.
