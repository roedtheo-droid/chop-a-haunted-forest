---
category: Shapes
---
A chunky block with cut edges, the main building piece. With `top` and `shift` it also makes trunks, teeth, roots and roofs.

```jsx
<ModelStage>
  <ModelPart name="Trunk" color="bark">
    <Block size={[6, 8, 6]} at={[0, 0, 0]} standing top={0.75} shift={[0.4, 0]} bevel={0.3} />
  </ModelPart>
</ModelStage>
```

- `size` is width, height and depth in studs.
- `at` is the block's middle. Add `standing` to make it the bottom middle, which is easier for things standing on the ground.
- `turn` is in degrees around X, Y and Z, like Roblox's CFrame.Angles.
- `top` shrinks the top: `0.8` for a trunk, `0.12` for a tooth, `[1, 0.05]` for a wedge.
- `bevel` is what makes the game's chunky look. Use about 5% of the block's size, and never leave a big block sharp.
- Keep shapes angular. The game's style has no spheres and no round trunks.
