---
category: Shapes
---
A block with several sides, for anything roundish in a game that has no spheres: eyes, coins, barrels and knots in the wood.

```jsx
<ModelStage>
  <ModelPart name="Barrel" color="plank">
    <Prism sides={10} radius={1.6} height={3.4} at={[0, 1.7, 0]} bevel={0.2} />
  </ModelPart>
</ModelStage>
```

- It stands along Y. Use `turn={[90, 0, 0]}` to make its round face look at the front, like an eye.
- Keep `sides` between 6 and 12. More sides stop looking chunky and cost more triangles.
- `top` tapers it: below 1 makes a bulge like an eyeball or a pot.
