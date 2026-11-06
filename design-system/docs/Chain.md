---
category: Shapes
---
A sagging chain of links between two points. Each link is turned against the one before it, like a real chain.

```jsx
<ModelStage>
  <ModelPart name="Chain" color="iron">
    <Chain from={[-4, 4, 0]} to={[4, 4, 0]} sag={1.6} />
  </ModelPart>
</ModelStage>
```

- `from` and `to` are in the same studs as everything else.
- `sag` is how far its middle hangs below a straight line. Use 0 for a chain pulled tight.
- Leave `links` out and it picks a number that fits the length.
