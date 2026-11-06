---
category: Models
---
A ghost: a chunky floating sheet with long eyes and an "O" mouth, the kind that scares players in the forest.

```jsx
<Ghost width={480} height={400} floating spin={20} />
```

- `floating` makes it bob up and down, the way it moves in the game.
- It takes the stage's camera props too, like `yaw`, `pitch`, `spin` and `person`.
- Its body is see-through, so its face shows faintly from behind.
