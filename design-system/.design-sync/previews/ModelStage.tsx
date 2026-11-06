import { Block, ModelPart, ModelStage } from "trees-with-teeth-3d";

const Stump = () => (
  <>
    <ModelPart name="Trunk" color="bark">
      <Block size={[6, 3, 6]} standing top={0.85} bevel={0.3} />
      <Block size={[1.6, 1.2, 3]} at={[0, 0.4, 3.6]} top={[0.5, 0.3]} bevel={0.15} />
      <Block size={[3, 1.2, 1.6]} at={[3.6, 0.4, 0]} top={[0.3, 0.5]} bevel={0.15} />
      <Block size={[3, 1.2, 1.6]} at={[-3.6, 0.4, 0]} top={[0.3, 0.5]} bevel={0.15} />
    </ModelPart>
    <ModelPart name="Rings" color="innerWood">
      <Block size={[4.5, 0.1, 4.5]} at={[0, 3.04, 0]} bevel={0.04} />
    </ModelPart>
  </>
);

/** A stump, framed by the stage on its own. */
export const Framed = () => (
  <ModelStage name="Stump" width={420} height={300}>
    <Stump />
  </ModelStage>
);

/** With a person next to it, to show its size in the game. */
export const WithPerson = () => (
  <ModelStage name="Stump" width={420} height={300} person yaw={-30}>
    <Stump />
  </ModelStage>
);

/** Looking down from above, on a dark background with no ground. */
export const FromAbove = () => (
  <ModelStage name="Stump" width={420} height={300} pitch={55} ground={false} background="edge">
    <Stump />
  </ModelStage>
);
