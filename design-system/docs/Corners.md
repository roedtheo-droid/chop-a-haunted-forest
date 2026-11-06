---
category: Shapes
---
A block with its 8 corners placed by hand, for shapes a Block can't make: a root that hugs the ground, or a stump cut at a slant.

```jsx
<ModelStage>
  <ModelPart name="Root" color="root">
    <Corners
      bevel={0.14}
      points={[
        [-1, 0, 0], [1, 0, 0], [-1, 2, 0], [1, 2, 0],
        [-0.3, 0, 4], [0.3, 0, 4], [-0.2, 0.3, 4], [0.2, 0.3, 4],
      ]}
    />
  </ModelPart>
</ModelStage>
```

- Give exactly 8 points in this order: left-bottom-back, right-bottom-back, left-top-back, right-top-back, then the same four at the front.
- Keep the shape convex, with no dents. For a dent, use two shapes.
- Try a Block with `top` and `shift` first. Use this only when those can't make the shape.
