---
category: Models
---
Gnawbert, the game's mascot: a chained stump mimic that eats logs at the sawmill and burps up coins.

```jsx
<Gnawbert width={640} height={480} mouth={0.6} person />
```

- `mouth` opens its lid, from 0 (shut) to 1 (as wide as it goes).
- `chomping` keeps it snapping shut, the way it eats.
- It takes the stage's camera props too, like `yaw`, `pitch`, `spin` and `person`.
- It's about 10 studs tall, nearly twice a player's height.
