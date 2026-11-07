import { Block } from "../shapes/Block";
import { Corners } from "../shapes/Corners";
import { Prism } from "../shapes/Prism";
import { Skin } from "../shapes/Skin";
import { lerp } from "../core/math";
import type { Vec3 } from "../core/math";
import { ModelStage } from "../stage/ModelStage";
import type { ModelStageProps } from "../stage/ModelStage";
import { ModelPart } from "../structure/ModelPart";
import { MovingGroup } from "../structure/MovingGroup";
import { Place } from "../structure/Place";
import { BarRing, boxPoints } from "./pieces";

export interface GhostKeeperProps extends Pick<ModelStageProps, "width" | "height" | "yaw" | "pitch" | "spin" | "person" | "ground" | "background" | "distance" | "target" | "style"> {
  /** Bobs up and down on the stage, the way it floats behind the counter. */
  floating?: boolean;
  /** Shows the shed's counter in front of it. It's only on the board. */
  counter?: boolean;
}

// Built like the ghosts in the forest, but bigger and kinder. The numbers inside are for a head 2.6
// studs wide, and the whole ghost is scaled up by SCALE. It floats above y = 0, behind a counter.
const SCALE = 1.25;
const FLOAT = 5.8; // how high the middle of its head is

const BODY = [
  { y: 1.42, width: 0.56, depth: 0.5, z: 0 },
  { y: 1.3, width: 1.02, depth: 0.92, z: 0 },
  { y: 0.92, width: 1.28, depth: 1.18, z: 0 },
  { y: 0.1, width: 1.34, depth: 1.24, z: 0 },
  { y: -0.7, width: 1.34, depth: 1.26, z: 0 },
  { y: -1.4, width: 1.44, depth: 1.34, z: -0.04 },
  { y: -2.05, width: 1.66, depth: 1.52, z: -0.1, wave: 0.3 },
  { y: -1.72, width: 1.18, depth: 1.08, z: -0.1 },
];

const FACE_Z = 1.2;

/** How far its belly reaches out at height `y`, for laying the apron on it. */
function bellyZ(y: number): number {
  for (let i = 2; i < 6; i++) {
    const a = BODY[i], b = BODY[i + 1];
    if (y <= a.y && y >= b.y) {
      const t = (a.y - y) / (a.y - b.y);
      return lerp(a.z + a.depth, b.z + b.depth, t);
    }
  }
  return 1.2;
}

const BIB_TOP = -0.66;
const BIB_BOTTOM = -1.92;

/** The apron: one flat piece on its belly, wider at the bottom. A band around its waist holds it. */
function ApronSheet() {
  return (
    <Corners
      bevel={0.05}
      points={boxPoints((sx, sy, sz) => {
        const y = sy > 0 ? BIB_TOP : BIB_BOTTOM;
        const w = sy > 0 ? 0.9 : 1.14;
        return [sx * w, y, bellyZ(y) + (sz > 0 ? 0.08 : -0.3)];
      })}
    />
  );
}

function Arm() {
  return (
    <Place at={[1.3, -0.5, 0.7]} turn={[112, 0, 12]}>
      <Block size={[0.76, 1.5, 0.7]} standing top={0.76} bevel={0.22} />
    </Place>
  );
}

function Pieces({ counter }: { counter: boolean }) {
  return (
    <>
      <ModelPart name="Pivot" color="ironDark" hidden>
        <Block size={[0.2, 0.2, 0.2]} at={[0, 0.1, 0]} bevel={0} />
      </ModelPart>
      <Place at={[0, FLOAT, 0]} scale={SCALE}>
        <ModelPart name="Body" color="ghost" alpha={0.86}>
          <Skin rings={BODY} sides={24} squareness={3} waves={4} />
        </ModelPart>
        <ModelPart name="Arm" color="ghost" alpha={0.86}>
          <Arm />
          <Place mirror>
            <Arm />
          </Place>
        </ModelPart>

        <ModelPart name="Eye" color="throat">
          <Block size={[0.44, 0.58, 0.14]} at={[-0.46, 0.44, FACE_Z]} bevel={0.12} />
          <Block size={[0.44, 0.58, 0.14]} at={[0.46, 0.44, FACE_Z]} bevel={0.12} />
        </ModelPart>
        <ModelPart name="Glint" color="bone">
          <Block size={[0.13, 0.17, 0.04]} at={[-0.53, 0.56, FACE_Z + 0.08]} bevel={0} />
          <Block size={[0.13, 0.17, 0.04]} at={[0.39, 0.56, FACE_Z + 0.08]} bevel={0} />
        </ModelPart>
        <ModelPart name="Glasses" color="brass">
          <BarRing radius={0.42} bars={8} width={0.07} depth={0.07} at={[-0.46, 0.44, FACE_Z + 0.1]} start={Math.PI / 8} />
          <BarRing radius={0.42} bars={8} width={0.07} depth={0.07} at={[0.46, 0.44, FACE_Z + 0.1]} start={Math.PI / 8} />
          <Block size={[0.12, 0.07, 0.07]} at={[0, 0.46, FACE_Z + 0.1]} bevel={0} />
        </ModelPart>
        <ModelPart name="Mustache" color="barkDark">
          <Block size={[0.72, 0.24, 0.14]} at={[-0.36, -0.12, FACE_Z + 0.03]} turn={[0, 0, 16]} top={[0.62, 1]} bevel={0.05} />
          <Block size={[0.72, 0.24, 0.14]} at={[0.36, -0.12, FACE_Z + 0.03]} turn={[0, 0, -16]} top={[0.62, 1]} bevel={0.05} />
        </ModelPart>
        <ModelPart name="Mouth" color="throat">
          <Block size={[0.36, 0.1, 0.1]} at={[0, -0.42, FACE_Z]} bevel={0} />
          <Block size={[0.17, 0.1, 0.1]} at={[-0.24, -0.38, FACE_Z]} turn={[0, 0, -32]} bevel={0} />
          <Block size={[0.17, 0.1, 0.1]} at={[0.24, -0.38, FACE_Z]} turn={[0, 0, 32]} bevel={0} />
        </ModelPart>

        <Place at={[0, 1.2, -0.02]} turn={[-3, 0, -5]}>
          <ModelPart name="Hat" color="edge">
            <Prism sides={12} radius={1.34} height={0.14} at={[0, 0, 0]} bevel={0.05} />
            <Prism sides={12} radius={0.92} height={0.66} at={[0, 0.4, 0]} top={0.86} bevel={0.1} />
          </ModelPart>
          <ModelPart name="HatBand" color="plank">
            <Prism sides={12} radius={0.95} height={0.16} at={[0, 0.16, 0]} top={0.97} bevel={0.02} />
          </ModelPart>
        </Place>

        <ModelPart name="Apron" color="plank">
          <ApronSheet />
        </ModelPart>
        <ModelPart name="Strap" color="plankDark">
          <Skin
            rings={[
              { y: BIB_TOP + 0.1, width: 1.37, depth: 1.29 },
              { y: BIB_TOP - 0.1, width: 1.37, depth: 1.29 },
            ]}
            sides={24}
            squareness={3}
            waves={0}
          />
          <Block size={[1, 0.36, 0.08]} at={[0, -1.22, bellyZ(-1.22) + 0.1]} bevel={0.03} />
          {/* The bow it's tied with, at the back. */}
          <Block size={[0.62, 0.34, 0.14]} at={[-0.3, BIB_TOP, -1.34]} turn={[0, 0, 22]} top={[1, 0.8]} bevel={0.04} />
          <Block size={[0.62, 0.34, 0.14]} at={[0.3, BIB_TOP, -1.34]} turn={[0, 0, -22]} top={[1, 0.8]} bevel={0.04} />
        </ModelPart>
      </Place>
      {counter && (
        <ModelPart name="ShownCounter" color="plank" stage>
          <Block size={[10, 3.8, 2.8]} at={[0, 0, 2.9]} standing bevel={0.1} />
        </ModelPart>
      )}
    </>
  );
}

/**
 * The Tool Shed's shopkeeper: a friendly ghost in spectacles, a bowler hat and a leather apron. Only
 * its top half shows over the counter, so the apron starts low.
 *
 * @category Models
 */
export function GhostKeeper(props: GhostKeeperProps): JSX.Element {
  const { floating = false, counter = false, ...stage } = props;
  return (
    <ModelStage name="GhostKeeper" label="A friendly ghost shopkeeper with spectacles, a bowler hat and an apron" {...stage}>
      <MovingGroup name="Float" sway={[0, 0.16, 0]} speed={floating ? 0.3 : 0}>
        <Pieces counter={counter} />
      </MovingGroup>
    </ModelStage>
  );
}
