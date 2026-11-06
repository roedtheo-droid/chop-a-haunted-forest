import { Block, ModelPart, ModelStage, Tooth } from "trees-with-teeth-3d";

const ROW: [number, number][] = [[-3, 1.4], [-1.8, 2.4], [-0.6, 1.2], [0.6, 1.7], [2, 2.6], [3.1, 1.2]];

/** Uneven teeth standing on a gum. */
export const BottomRow = () => (
  <ModelStage width={420} height={280} pitch={8}>
    <ModelPart name="Gum" color="gum">
      <Block size={[7.6, 0.6, 2]} standing bevel={0.14} />
    </ModelPart>
    <ModelPart name="Teeth" color="bone">
      {ROW.map(([x, length]) => (
        <Tooth key={x} width={1.05} length={length} depth={0.8} at={[x, 0.55, 0]} />
      ))}
    </ModelPart>
  </ModelStage>
);

/** `down` makes the top row of a mouth, hanging from a bark lip. */
export const TopRow = () => (
  <ModelStage width={420} height={280} pitch={4} ground={false}>
    <ModelPart name="Lip" color="bark">
      <Block size={[7.6, 1.2, 2]} at={[0, 3.6, 0]} bevel={0.2} />
    </ModelPart>
    <ModelPart name="Fangs" color="bone">
      {ROW.map(([x, length]) => (
        <Tooth key={x} width={1.05} length={length} depth={0.8} at={[x, 3.05, 0]} down />
      ))}
    </ModelPart>
  </ModelStage>
);

/** A wider `tip` makes a stubby, broken tooth. */
export const Stubby = () => (
  <ModelStage width={420} height={280} pitch={10} background="throat" ground={false}>
    <ModelPart name="Teeth" color="bone">
      <Tooth width={2} length={2.4} depth={1.6} at={[-1.6, 0, 0]} tip={0.5} />
      <Tooth width={2} length={3.2} depth={1.6} at={[1.2, 0, 0]} tip={0.3} />
    </ModelPart>
  </ModelStage>
);
