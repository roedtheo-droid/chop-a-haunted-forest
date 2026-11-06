import { Block, ModelPart, ModelStage } from "trees-with-teeth-3d";

/** Each colour is its own part. */
export const TwoParts = () => (
  <ModelStage width={360} height={260}>
    <ModelPart name="Trunk" color="bark">
      <Block size={[5, 6, 5]} standing top={0.8} bevel={0.3} />
    </ModelPart>
    <ModelPart name="Moss" color="moss">
      <Block size={[3.6, 0.5, 3.6]} at={[0, 6.1, 0]} bevel={0.15} />
    </ModelPart>
  </ModelStage>
);

/** `glow` lights a part up, for things that are Neon in the game. */
export const Glowing = () => (
  <ModelStage width={360} height={260} background="throat" ground={false}>
    <ModelPart name="Stone" color="iron">
      <Block size={[5, 5, 2]} standing top={0.8} bevel={0.3} />
    </ModelPart>
    <ModelPart name="Eye" color="amber" glow={0.8}>
      <Block size={[1, 1, 0.3]} at={[-1, 3.1, 1]} bevel={0.1} />
      <Block size={[1, 1, 0.3]} at={[1, 3.1, 1]} bevel={0.1} />
    </ModelPart>
  </ModelStage>
);

/** `alpha` makes a part see-through on the board. */
export const SeeThrough = () => (
  <ModelStage width={360} height={260}>
    <ModelPart name="Body" color="ghost" alpha={0.7}>
      <Block size={[4, 6, 4]} at={[0, 1, 0]} standing top={0.7} bevel={0.5} />
    </ModelPart>
  </ModelStage>
);
