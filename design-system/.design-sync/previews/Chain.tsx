import { Block, Chain, ModelPart, ModelStage } from "trees-with-teeth-3d";

const Posts = () => (
  <ModelPart name="Post" color="bark">
    <Block size={[1, 5, 1]} at={[-5, 0, 0]} standing top={0.8} bevel={0.12} />
    <Block size={[1, 5, 1]} at={[5, 0, 0]} standing top={0.8} bevel={0.12} />
  </ModelPart>
);

/** Hanging between two posts. */
export const Sagging = () => (
  <ModelStage width={420} height={280} pitch={8}>
    <Posts />
    <ModelPart name="Chain" color="iron">
      <Chain from={[-4.6, 4.4, 0]} to={[4.6, 4.4, 0]} sag={2} />
    </ModelPart>
  </ModelStage>
);

/** `sag` of 0 pulls it tight. */
export const Tight = () => (
  <ModelStage width={420} height={280} pitch={8}>
    <Posts />
    <ModelPart name="Chain" color="iron">
      <Chain from={[-4.6, 3, 0]} to={[4.6, 3, 0]} sag={0} />
    </ModelPart>
  </ModelStage>
);

/** Bigger links, set with `width` and `thickness`. */
export const Heavy = () => (
  <ModelStage width={420} height={280} pitch={8} background="edge" ground={false}>
    <ModelPart name="Chain" color="iron">
      <Chain from={[-4, 4, 0]} to={[4, 3, 0]} links={5} sag={1} width={1.1} thickness={0.26} />
    </ModelPart>
  </ModelStage>
);
