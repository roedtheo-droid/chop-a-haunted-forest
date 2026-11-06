import { ModelPart, ModelStage, Prism } from "trees-with-teeth-3d";

/** A barrel: a ten-sided block with iron bands. */
export const Barrel = () => (
  <ModelStage width={420} height={280}>
    <ModelPart name="Barrel" color="plank">
      <Prism sides={10} radius={1.7} height={3.6} at={[0, 1.8, 0]} bevel={0.22} />
    </ModelPart>
    <ModelPart name="Hoop" color="ironDark">
      <Prism sides={10} radius={1.76} height={0.3} at={[0, 0.9, 0]} bevel={0.04} />
      <Prism sides={10} radius={1.76} height={0.3} at={[0, 2.7, 0]} bevel={0.04} />
    </ModelPart>
  </ModelStage>
);

/** `turn` faces it forward and `top` bulges it: an eye in its socket. */
export const Eye = () => (
  <ModelStage width={420} height={280} yaw={18} pitch={4} ground={false} background="edge">
    <ModelPart name="Socket" color="gum">
      <Prism sides={8} radius={1.9} height={0.3} at={[0, 3, 0]} turn={[90, 0, 0]} bevel={0.06} />
    </ModelPart>
    <ModelPart name="Eye" color="amber" glow={0.3}>
      <Prism sides={10} radius={1.6} height={0.7} at={[0, 3, 0.3]} turn={[90, 0, 0]} top={0.84} bevel={0.14} />
    </ModelPart>
    <ModelPart name="Pupil" color="throat">
      <Prism sides={6} radius={0.6} height={0.2} at={[0, 3, 0.72]} turn={[90, 0, 0]} bevel={0.04} />
    </ModelPart>
  </ModelStage>
);

/** Low and wide: a stack of coins. */
export const Coins = () => (
  <ModelStage width={420} height={280} pitch={22}>
    <ModelPart name="Coin" color="brass">
      {[0, 1, 2, 3].map((i) => (
        <Prism key={i} sides={8} radius={1} height={0.3} at={[i * 0.05, 0.15 + i * 0.3, -i * 0.04]} turn={[0, i * 22, 0]} bevel={0.05} />
      ))}
      <Prism sides={8} radius={1} height={0.3} at={[2.2, 0.15, 0.6]} turn={[0, 12, 0]} bevel={0.05} />
    </ModelPart>
  </ModelStage>
);
