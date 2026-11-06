import { Block } from "../shapes/Block";
import { Prism } from "../shapes/Prism";
import { Skin } from "../shapes/Skin";
import type { Vec3 } from "../core/math";
import { ModelStage } from "../stage/ModelStage";
import type { ModelStageProps } from "../stage/ModelStage";
import { ModelPart } from "../structure/ModelPart";
import { MovingGroup } from "../structure/MovingGroup";
import { Place } from "../structure/Place";

export interface GhostProps extends Pick<ModelStageProps, "width" | "height" | "yaw" | "pitch" | "spin" | "person" | "ground" | "background" | "distance" | "target" | "style"> {
  /** Bobs up and down on the stage, the way it floats in the game. */
  floating?: boolean;
}

// Its head is 2.6 studs wide, the size of Config.Ghosts.Size in the game. It floats above y = 0.
const FLOAT = 3.3; // how high the middle of its head is
const LEAN = 8; // degrees it leans into the way it's going

const BODY = [
  { y: 1.42, width: 0.56, depth: 0.5, z: 0 },
  { y: 1.3, width: 1.02, depth: 0.92, z: 0 },
  { y: 0.92, width: 1.28, depth: 1.18, z: 0 },
  { y: 0.1, width: 1.32, depth: 1.22, z: -0.04 },
  { y: -0.7, width: 1.26, depth: 1.16, z: -0.14 },
  { y: -1.4, width: 1.4, depth: 1.28, z: -0.26 },
  { y: -2.05, width: 1.64, depth: 1.5, z: -0.42, wave: 0.3 },
  { y: -1.72, width: 1.18, depth: 1.08, z: -0.42 },
];

const FACE_Z = 1.2;

function Arm() {
  const at: Vec3 = [1.5, -0.3, 0.38];
  return (
    <Place at={at} turn={[-34, 0, -30]}>
      <Block size={[0.84, 1.15, 0.76]} standing top={0.72} bevel={0.24} />
    </Place>
  );
}

function Pieces() {
  return (
    <>
      <ModelPart name="Pivot" color="ironDark" hidden>
        <Block size={[0.2, 0.2, 0.2]} at={[0, 0.1, 0]} bevel={0} />
      </ModelPart>
      <Place at={[0, FLOAT, 0]} turn={[LEAN, 0, 0]}>
        <ModelPart name="Body" color="ghost" alpha={0.84}>
          <Skin rings={BODY} sides={24} squareness={3} waves={4} />
        </ModelPart>
        <ModelPart name="Arm" color="ghost" alpha={0.84}>
          <Arm />
          <Place mirror>
            <Arm />
          </Place>
        </ModelPart>
        <ModelPart name="Eye" color="throat">
          <Block size={[0.6, 0.92, 0.16]} at={[-0.52, 0.42, FACE_Z]} turn={[0, -8, 6]} bevel={0.15} />
          <Block size={[0.6, 0.92, 0.16]} at={[0.52, 0.42, FACE_Z]} turn={[0, 8, -6]} bevel={0.15} />
        </ModelPart>
        <ModelPart name="Mouth" color="throat">
          <Prism sides={8} radius={0.28} height={0.14} at={[0, -0.32, FACE_Z + 0.02]} turn={[90, 0, 0]} bevel={0.04} />
        </ModelPart>
      </Place>
    </>
  );
}

/**
 * A ghost: a chunky floating sheet with long eyes and an "O" mouth. Its body is one skin, so it
 * stays clean when it's see-through.
 *
 * @category Models
 */
export function Ghost(props: GhostProps): JSX.Element {
  const { floating = false, ...stage } = props;
  return (
    <ModelStage name="Ghost" label="A chunky white ghost with long dark eyes and a round mouth" {...stage}>
      <MovingGroup name="Float" sway={[0, 0.3, 0]} speed={floating ? 0.35 : 0}>
        <Pieces />
      </MovingGroup>
    </ModelStage>
  );
}
