---
category: Stage
---
Shows a 3D model live, and people can drag it to look all around. Every model starts with one.

Put the model's pieces inside it. Nothing else belongs inside: ordinary page elements are ignored.

```jsx
<ModelStage name="Stump" width={480} height={360} person spin={20}>
  <ModelPart name="Trunk" color="bark">
    <Block size={[6, 3, 6]} at={[0, 0, 0]} standing top={0.85} bevel={0.3} />
  </ModelPart>
  <ModelPart name="Rings" color="innerWood">
    <Block size={[4.6, 0.1, 4.6]} at={[0, 3.04, 0]} bevel={0.04} />
  </ModelPart>
</ModelStage>
```

- Sizes are studs, Roblox's units. A player is about 5.5 studs tall; turn on `person` to compare.
- +Y is up and +Z is the model's front. Build models facing +Z.
- The camera frames the model by itself, so only set `distance` and `target` to get closer.
- Your own model component must be a plain function with no hooks, because the stage reads it as data instead of rendering it.
- If `spin` is set, the model turns slowly until someone drags it.
