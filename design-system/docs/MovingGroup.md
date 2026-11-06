---
category: Structure
---
Parts that move together around a hinge, like a jaw or a lid. Use it to see how a model will move in the game.

```jsx
<ModelStage>
  <MovingGroup name="Lid" hinge={[0, 3, -2]} angle={-20} swing={15} speed={0.8}>
    <ModelPart name="Lid" color="bark">
      <Block size={[5, 2, 5]} at={[0, 3, 0]} standing />
    </ModelPart>
  </MovingGroup>
</ModelStage>
```

- Put the `hinge` where the part really turns. With a hinge at the back, a negative `angle` lifts the front.
- `swing` and `speed` keep it moving on the stage. `slide` and `sway` move it without turning.
- Groups can nest: pupils inside a lid move with the lid and also look around.
- The movement only shows on the stage. Models go to Roblox at rest, with no angle, and the game moves the parts by their names.
