---
category: Models
---
A wanted poster of a mimic, nailed to a wall. It hangs flat, with z = 0 on the wall.

```jsx
<WantedPoster width={420} height={540} sketch="B" yaw={0} pitch={0} />
```

- `sketch` picks the drawing: `"A"` is a grinning pine, `"B"` a stump with its mouth open, and `"C"` an oak running away. All three go to Roblox, and the game keeps the one it needs.
- `words` shows bars where the words go. They're only on the board, because the game writes the real words on the paper.
- It takes the stage's camera props too, like `yaw`, `pitch` and `spin`.
