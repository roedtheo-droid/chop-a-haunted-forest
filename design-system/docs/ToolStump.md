---
category: Models
---
A tree stump that shows one tool in the Tool Shed, with a lantern hanging over it from a post behind.

```jsx
<ToolStump width={480} height={560} yaw={24} pitch={10} person />
```

- `dressed` shows an axe floating above the stump and a price plate on its front, the way the game dresses it. They're only on the board: the game puts the real tool and plate there. Set it to `false` to see the stump alone.
- It takes the stage's camera props too, like `yaw`, `pitch`, `spin` and `person`.
