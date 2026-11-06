import { Block, ModelPart, ModelStage } from "trees-with-teeth-3d";

/** A plain block with cut edges. */
export const Plain = () => (
  <ModelStage width={320} height={240}>
    <ModelPart name="Crate" color="plank">
      <Block size={[4, 4, 4]} standing bevel={0.3} />
    </ModelPart>
  </ModelStage>
);

/** `top` and `shift` make a leaning trunk. */
export const Trunk = () => (
  <ModelStage width={320} height={240}>
    <ModelPart name="Trunk" color="bark">
      <Block size={[3.4, 9, 3.4]} standing top={0.6} shift={[0.9, 0]} bevel={0.25} />
    </ModelPart>
  </ModelStage>
);

/** A small `top` makes a point: a row of teeth. */
export const Teeth = () => (
  <ModelStage width={320} height={240}>
    <ModelPart name="Gum" color="gum">
      <Block size={[7, 0.6, 2]} standing bevel={0.12} />
    </ModelPart>
    <ModelPart name="Teeth" color="bone">
      {[-2.6, -1.3, 0, 1.3, 2.6].map((x, i) => (
        <Block key={x} size={[1.1, i % 2 ? 2.4 : 1.7, 1]} at={[x, 0.55, 0]} standing top={0.14} bevel={0.06} />
      ))}
    </ModelPart>
  </ModelStage>
);

/** `top` on one axis makes a wedge, and `turn` lays it over. */
export const Wedge = () => (
  <ModelStage width={320} height={240} yaw={62} pitch={12}>
    <ModelPart name="Roof" color="berry">
      <Block size={[6, 3, 5]} standing top={[1, 0.04]} bevel={0.12} />
    </ModelPart>
  </ModelStage>
);
