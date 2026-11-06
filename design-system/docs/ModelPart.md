---
category: Structure
---
One part of a model: one colour, and one MeshPart in Roblox Studio. Shapes go inside it.

```jsx
<ModelStage>
  <ModelPart name="Trunk" color="bark">
    <Block size={[6, 8, 6]} standing top={0.8} bevel={0.3} />
  </ModelPart>
  <ModelPart name="Teeth" color="bone">
    <Block size={[1, 1.6, 0.6]} at={[-1.5, 4, 2.7]} top={0.15} bevel={0.05} />
    <Block size={[1, 1.6, 0.6]} at={[1.5, 4, 2.7]} top={0.15} bevel={0.05} />
  </ModelPart>
</ModelStage>
```

- Use one part per colour, not one part per shape. Fewer parts run faster in the game.
- Names matter: the game finds parts by name to paint and move them. Use clear names like "Trunk", "Teeth" or "Eye".
- Every shape inside takes the part's colour.
- The game paints parts itself, so colours show the look but aren't stored as a texture.
