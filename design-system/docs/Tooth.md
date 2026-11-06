---
category: Shapes
---
A chunky tooth that tapers to a blunt tip. Teeth are the game's signature, so make them big and uneven.

```jsx
<ModelStage>
  <ModelPart name="Teeth" color="bone">
    <Tooth width={1.1} length={2.2} at={[-1.2, 0, 0]} />
    <Tooth width={1.1} length={1.4} at={[0, 0, 0]} />
    <Tooth width={1.1} length={1.8} at={[1.2, 0, 0]} />
  </ModelPart>
</ModelStage>
```

- `at` is where its root is, not its middle, so a row of teeth lines up by giving them the same height.
- `down` points it down, for the top row of a mouth.
- Vary `length` from tooth to tooth, and leave a gap somewhere. Even rows look like a saw instead of a mouth.
- It also works for claws, thorns and spikes.
