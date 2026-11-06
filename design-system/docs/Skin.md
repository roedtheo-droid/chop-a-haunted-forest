---
category: Shapes
---
One closed skin stretched through rings, for soft bodies like a ghost's sheet. It stays clean when see-through, because it has no faces hidden inside it.

```jsx
<ModelStage>
  <ModelPart name="Body" color="ghost" alpha={0.85}>
    <Skin
      at={[0, 3, 0]}
      rings={[
        { y: 1.4, width: 0.5 },
        { y: 1.2, width: 1.1 },
        { y: 0, width: 1.3 },
        { y: -2, width: 1.6, wave: 0.3 },
        { y: -1.7, width: 1.2 },
      ]}
    />
  </ModelPart>
</ModelStage>
```

- List the rings in order from one end to the other, each with its height `y` and half-width `width`.
- `wave` makes one ring wavy, which gives a sheet its torn hem.
- `squareness` keeps the shape from going smooth: 2 is an oval, and 3 or more fits the game's chunky look.
- Finish with a smaller ring just inside the last one, so the open end has a closed underside.
