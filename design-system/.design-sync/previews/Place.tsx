import { Block, ModelPart, ModelStage, Place, Tooth } from "trees-with-teeth-3d";

const Head = () => (
  <ModelPart name="Head" color="bark">
    <Block size={[5, 4, 4]} standing top={0.85} bevel={0.3} />
  </ModelPart>
);

const Horn = () => (
  <Place at={[1.6, 3.9, 0]} turn={[0, 0, -22]}>
    <Tooth width={1.1} length={2.6} />
  </Place>
);

/** `mirror` reuses one horn for the other side. */
export const Mirrored = () => (
  <ModelStage width={420} height={300} yaw={14}>
    <Head />
    <ModelPart name="Horn" color="bone">
      <Horn />
      <Place mirror>
        <Horn />
      </Place>
    </ModelPart>
  </ModelStage>
);

/** `turn` and `at` make a ring from one piece. */
export const Ring = () => (
  <ModelStage width={420} height={300} pitch={30}>
    <ModelPart name="Stone" color="iron">
      {[0, 45, 90, 135, 180, 225, 270, 315].map((angle) => (
        <Place key={angle} turn={[0, angle, 0]}>
          <Block size={[1.2, 2.4, 0.9]} at={[0, 0, 4]} standing top={0.75} bevel={0.14} />
        </Place>
      ))}
    </ModelPart>
  </ModelStage>
);

/** `scale` resizes everything inside it together. */
export const Scaled = () => (
  <ModelStage width={420} height={300} yaw={10}>
    <Place at={[-3.4, 0, 0]} scale={1.4}>
      <Head />
    </Place>
    <Place at={[3.4, 0, 0]} scale={0.7}>
      <Head />
    </Place>
  </ModelStage>
);
