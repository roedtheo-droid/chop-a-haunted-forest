import { Block, ModelPart, ModelStage, MovingGroup, Tooth } from "trees-with-teeth-3d";

function Box({ angle, swing, speed }: { angle: number; swing?: number; speed?: number }) {
  return (
    <>
      <ModelPart name="Base" color="plankDark">
        <Block size={[5, 2.4, 5]} standing bevel={0.2} />
      </ModelPart>
      <ModelPart name="Gum" color="gum">
        <Block size={[4.4, 0.1, 4.4]} at={[0, 2.42, 0]} bevel={0.02} />
      </ModelPart>
      <MovingGroup name="Lid" hinge={[0, 2.5, -2.4]} angle={angle} swing={swing} speed={speed}>
        <ModelPart name="Lid" color="plank">
          <Block size={[5.2, 1.6, 5.2]} at={[0, 2.5, 0]} standing top={0.85} bevel={0.22} />
        </ModelPart>
        <ModelPart name="Fangs" color="bone">
          {[-1.8, -0.6, 0.6, 1.8].map((x, i) => (
            <Tooth key={x} width={0.9} length={i % 2 ? 0.8 : 1.2} depth={0.6} at={[x, 2.5, 2.2]} down />
          ))}
        </ModelPart>
      </MovingGroup>
    </>
  );
}

/** With the hinge at the back, a negative `angle` lifts the front. */
export const Open = () => (
  <ModelStage width={420} height={300} yaw={30}>
    <Box angle={-40} />
  </ModelStage>
);

/** With no `angle` it sits at rest, the way it goes to Roblox. */
export const AtRest = () => (
  <ModelStage width={420} height={300} yaw={30}>
    <Box angle={0} />
  </ModelStage>
);

/** `swing` and `speed` keep it moving on the stage. */
export const Chomping = () => (
  <ModelStage width={420} height={300} yaw={-30}>
    <Box angle={-22} swing={18} speed={0.8} />
  </ModelStage>
);
