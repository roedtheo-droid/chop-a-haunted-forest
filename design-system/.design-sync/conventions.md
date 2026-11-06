# Building 3D models with this kit

These components build 3D models for the Roblox game Trees With Teeth. The result is a live 3D view, not a page layout. When someone asks for a model, a creature, a tool or a prop, build it from these pieces. Read each component's `.prompt.md` first.

## Setup

Every model goes inside one `ModelStage`, which draws it. It needs no provider or theme. Only these pieces count inside it: `ModelPart`, `MovingGroup`, `Place`, the shapes (`Block`, `Tooth`, `Prism`, `Chain`, `Skin`, `Corners`), and your own helpers. Ordinary page elements inside a stage are ignored, so put captions and layout outside it.

Your own helper components must be plain functions with no hooks, because the stage reads them as data instead of rendering them. Don't use state or effects inside a model; pass props from outside the stage instead.

## How to style

There are no CSS classes for models. A part's look comes from its `color` prop and the shape of its pieces.

- `color` takes a palette name, "#rrggbb" or `[r, g, b]`. Prefer the names: `bark`, `barkLight`, `barkDark`, `root`, `innerWood`, `rings`, `bone`, `bite`, `tongue`, `gum`, `throat`, `iron`, `ironDark`, `brass`, `amber`, `moss`, `mossLight`, `pine`, `grass`, `dirt`, `plank`, `plankDark`, `edge`, `paper`, `ink`, `berry`, `ghost`, `cursed`, `water`, `mist`.
- For page designs around a model, the same colours are CSS variables in `styles.css`, named in kebab case: `var(--twt-bark)`, `var(--twt-inner-wood)`.
- The chunky look comes from `bevel` on `Block`. Use about 5% of the block's size. Build from angular shapes: no spheres and no smooth round trunks.

## The rules every model follows

- Sizes are in studs. A player is 5.5 studs tall; use `person` on the stage to compare.
- In the props, `Vec3` means a list `[x, y, z]` and `Rgb` means a list `[r, g, b]`.
- Build models facing +Z, standing on y = 0.
- Use one `ModelPart` per colour, with a clear name like `Trunk` or `Teeth`. The game finds parts by name.
- Anything the game moves goes in a `MovingGroup`, with its `hinge` where it really turns.
- Give the first part a tiny hidden Pivot box at the origin, which the game uses to place and size the model: `<ModelPart name="Pivot" hidden><Block size={[0.2, 0.2, 0.2]} at={[0, 0.1, 0]} bevel={0} /></ModelPart>`.
- The tone is a spooky storybook: cartoon scares and no gore. Avoid hot pink and loud green.

## A complete example

```jsx
const { ModelStage, ModelPart, MovingGroup, Block, Tooth, Prism } = window.TreesWithTeeth3D;

const Biter = () => (
  <>
    <ModelPart name="Pivot" hidden>
      <Block size={[0.2, 0.2, 0.2]} at={[0, 0.1, 0]} bevel={0} />
    </ModelPart>
    <ModelPart name="Trunk" color="bark">
      <Block size={[5, 3, 5]} standing top={0.9} bevel={0.3} />
    </ModelPart>
    <MovingGroup name="Lid" hinge={[0, 3.1, -2.2]} angle={-30}>
      <ModelPart name="Lid" color="barkLight">
        <Block size={[5, 2.4, 5]} at={[0, 3.1, 0]} standing top={0.8} bevel={0.3} />
      </ModelPart>
      <ModelPart name="Fangs" color="bone">
        <Tooth width={1} length={1.4} at={[-1.3, 3.1, 2]} down />
        <Tooth width={1} length={1} at={[1.3, 3.1, 2]} down />
      </ModelPart>
      <ModelPart name="Eye" color="amber" glow={0.3}>
        <Prism sides={8} radius={0.6} height={0.3} at={[-1, 4.4, 2.1]} turn={[80, 0, 0]} />
        <Prism sides={8} radius={0.6} height={0.3} at={[1, 4.4, 2.1]} turn={[80, 0, 0]} />
      </ModelPart>
    </MovingGroup>
  </>
);

<ModelStage name="Biter" width={640} height={480} person spin={20}>
  <Biter />
</ModelStage>
```

`Gnawbert` and `Ghost` are finished models to study. Their `.prompt.md` files show their props.
