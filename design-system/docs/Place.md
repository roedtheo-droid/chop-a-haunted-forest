---
category: Structure
---
Moves, turns, scales or mirrors a group of pieces together. Use it to build a detail once and put it in several places, like a pair of eyes or a ring of roots.

```jsx
const Horn = () => (
  <Place at={[1.4, 4, 0]} turn={[0, 0, -20]}>
    <Tooth width={1} length={2.4} />
  </Place>
);

<ModelStage>
  <ModelPart name="Horn" color="bone">
    <Horn />
    <Place mirror>
      <Horn />
    </Place>
  </ModelPart>
</ModelStage>
```

- It can wrap a `ModelPart`, or sit inside one.
- `mirror` flips left and right around X = 0.
- A helper like `Horn` above must be a plain function with no hooks.
