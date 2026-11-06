import { Fragment } from "react";
import { Block } from "../shapes/Block";
import { Chain } from "../shapes/Chain";
import { Corners } from "../shapes/Corners";
import { Prism } from "../shapes/Prism";
import { Tooth } from "../shapes/Tooth";
import { lerp } from "../core/math";
import type { Vec3 } from "../core/math";
import { ModelStage } from "../stage/ModelStage";
import type { ModelStageProps } from "../stage/ModelStage";
import { ModelPart } from "../structure/ModelPart";
import { MovingGroup } from "../structure/MovingGroup";
import { Place } from "../structure/Place";

export interface GnawbertProps extends Pick<ModelStageProps, "width" | "height" | "yaw" | "pitch" | "spin" | "person" | "ground" | "background" | "distance" | "target" | "style"> {
  /** How far its lid is open: 0 is shut, 1 is as wide as it goes. 0.25 by default. */
  mouth?: number;
  /** Keeps opening and snapping shut. */
  chomping?: boolean;
}

// The sizes it's built from, in studs. +Z is its front, and it stands on y = 0.
const SPLIT_Y = 4.4; // where the trunk ends and the lid begins
const LID_Y = 4.6;
const TOP_Y = 8.9;
const HINGE: Vec3 = [0, 4.55, -3.0];
const FACE_SLANT = 12.7; // degrees the lid's front leans back
const MOUTH_OPENS = 38; // degrees

const trunkX = (y: number) => lerp(4.4, 3.9, y / SPLIT_Y);
const trunkZ = (y: number) => lerp(4.0, 3.4, y / SPLIT_Y);
const lidT = (y: number) => (y - LID_Y) / (TOP_Y - LID_Y);
const lidX = (y: number) => lerp(4.15, 3.4, lidT(y));
const lidZ = (y: number) => lerp(3.85, 3.1, lidT(y));
const lidMiddleZ = (y: number) => lerp(0.12, -0.1, lidT(y));
const faceZ = (y: number) => lidMiddleZ(y) + lidZ(y);
/** The height of the slanted cut on top of the lid. */
const cutY = (x: number, z: number) => TOP_Y + 0.1 * x + 0.06 * z;
const CUT_TURN: Vec3 = [-3.4, 0, 5.7];

/** Eight corners between a rectangle low down and one higher up. */
function between(bottom: (sx: number, sz: number) => Vec3, top: (sx: number, sz: number) => Vec3): Vec3[] {
  const points: Vec3[] = [];
  for (let i = 0; i < 8; i++) {
    points.push((i & 2 ? top : bottom)(i & 1 ? 1 : -1, i & 4 ? 1 : -1));
  }
  return points;
}

type Side = "front" | "back" | "left" | "right";

/** A raised strip of bark on one side of a body whose size changes with height. */
function ridgePoints(side: Side, u: number, y0: number, y1: number, w: number, t: number, hx: (y: number) => number, hz: (y: number) => number, cz: (y: number) => number = () => 0): Vec3[] {
  const points: Vec3[] = [];
  for (let i = 0; i < 8; i++) {
    const y = i & 2 ? y1 : y0;
    const across = (i & 1 ? 1 : -1) * (w / 2);
    const out = i & 4 ? t : -0.08;
    if (side === "front") points.push([u * hx(y) + across, y, cz(y) + hz(y) + out]);
    else if (side === "back") points.push([u * hx(y) + across, y, cz(y) - hz(y) - out]);
    else if (side === "right") points.push([hx(y) + out, y, cz(y) + u * hz(y) + across]);
    else points.push([-hx(y) - out, y, cz(y) + u * hz(y) + across]);
  }
  return points;
}

const TRUNK_RIDGES: [Side, number, number, number, number][] = [
  ["front", -0.72, 0.3, 3.5, 0.62], ["front", -0.3, 0.2, 1.6, 0.5], ["front", 0.22, 0.2, 1.5, 0.56], ["front", 0.68, 0.3, 3.7, 0.66],
  ["back", -0.7, 0.2, 4.0, 0.7], ["back", -0.22, 0.4, 3.2, 0.5], ["back", 0.3, 0.2, 3.9, 0.62], ["back", 0.76, 0.5, 3.4, 0.5],
  ["right", -0.7, 0.2, 3.9, 0.66], ["right", -0.2, 0.6, 3.3, 0.5], ["right", 0.3, 0.2, 4.0, 0.62], ["right", 0.75, 0.4, 3.0, 0.5],
  ["left", -0.72, 0.4, 3.6, 0.6], ["left", -0.28, 0.2, 4.0, 0.5], ["left", 0.3, 0.3, 1.5, 0.62], ["left", 0.74, 0.3, 3.8, 0.56],
];

const LID_RIDGES: [Side, number, number, number, number][] = [
  ["front", -0.92, 4.9, 8.0, 0.5], ["front", 0.92, 4.9, 7.8, 0.5], ["front", 0.06, 7.9, 8.5, 0.6],
  ["back", -0.68, 4.8, 8.2, 0.66], ["back", -0.2, 5.1, 7.8, 0.5], ["back", 0.3, 4.8, 8.3, 0.62], ["back", 0.74, 5.0, 8.0, 0.5],
  ["right", -0.72, 4.9, 8.4, 0.6], ["right", -0.25, 5.2, 8.6, 0.5], ["right", 0.28, 4.8, 8.5, 0.64], ["right", 0.76, 5.1, 8.3, 0.5],
  ["left", -0.7, 4.8, 8.1, 0.62], ["left", -0.2, 5.0, 7.9, 0.5], ["left", 0.3, 5.2, 8.2, 0.6], ["left", 0.74, 4.9, 7.7, 0.5],
];

/** A root that hugs the ground, spreading out at `angle` degrees (0 is the front). */
function Root({ angle, length, width, height }: { angle: number; length: number; width: number; height: number }) {
  const a = (angle * Math.PI) / 180;
  const reach = 3.3;
  return (
    <Place at={[Math.sin(a) * reach, 0, Math.cos(a) * reach]} turn={[0, angle, 0]}>
      <Corners
        bevel={0.14}
        points={between(
          (sx, sz) => (sz < 0 ? [(sx * width) / 2, 0, 0] : [sx * width * 0.2, 0, length]),
          (sx, sz) => (sz < 0 ? [(sx * width) / 2, height, 0] : [sx * width * 0.16, 0.24, length]),
        )}
      />
    </Place>
  );
}

/** Square rings on the cut top of the lid, in the slant's own frame. */
function RingLines() {
  return (
    <>
      {[2.35, 1.45, 0.65].map((s) => (
        <Fragment key={s}>
          <Block size={[2.1 * s, 0.05, 0.13]} at={[0, 0.09, s * 0.88]} bevel={0} />
          <Block size={[2.1 * s, 0.05, 0.13]} at={[0, 0.09, -s * 0.88]} bevel={0} />
          <Block size={[0.13, 0.05, 1.76 * s]} at={[s * 1.05, 0.09, 0]} bevel={0} />
          <Block size={[0.13, 0.05, 1.76 * s]} at={[-s * 1.05, 0.09, 0]} bevel={0} />
        </Fragment>
      ))}
    </>
  );
}

/** One eye on the lid's face: `radius` studs wide, in the part given by `layer`. */
function EyeLayer({ x, y, radius, layer }: { x: number; y: number; radius: number; layer: "socket" | "eye" | "pupil" | "glint" }) {
  const at: Vec3 = [x, y, faceZ(y)];
  const turn: Vec3 = [90 - FACE_SLANT, 0, 0];
  return (
    <Place at={at} turn={turn}>
      {layer === "socket" && <Prism sides={8} radius={radius + 0.26} height={0.22} at={[0, 0.06, 0]} bevel={0.05} />}
      {layer === "eye" && <Prism sides={10} radius={radius} height={0.5} at={[0, 0.25, 0]} top={0.86} bevel={0.1} />}
      {layer === "pupil" && <Block size={[radius * 0.62, 0.12, radius * 1.02]} at={[0, 0.52, 0]} bevel={0.05} />}
      {layer === "glint" && <Block size={[radius * 0.2, 0.06, radius * 0.24]} at={[-radius * 0.12, 0.6, -radius * 0.26]} bevel={0} />}
    </Place>
  );
}

const EYES = [
  { x: -1.75, y: 7.15, radius: 1.12 },
  { x: 1.85, y: 7.0, radius: 0.88 },
];

function Pieces({ mouth, chomping }: { mouth: number; chomping: boolean }) {
  return (
    <>
      <ModelPart name="Pivot" color="ironDark" hidden>
        <Block size={[0.2, 0.2, 0.2]} at={[0, 0.1, 0]} bevel={0} />
      </ModelPart>

      {/* The bottom half stays still: it's chained up. */}
      <ModelPart name="Trunk" color="bark">
        <Block size={[8.8, SPLIT_Y, 8]} standing top={[3.9 / 4.4, 3.4 / 4]} bevel={0.3} />
        <Block size={[1.3, 3.8, 1.3]} at={[-8.75, 0, 1.25]} standing top={0.72} bevel={0.16} turn={[0, 20, -4]} />
      </ModelPart>
      <ModelPart name="Ridge" color="barkDark">
        {TRUNK_RIDGES.map(([side, u, y0, y1, w]) => (
          <Corners key={`${side}${u}`} bevel={0.08} points={ridgePoints(side, u, y0, y1, w, 0.2, trunkX, trunkZ)} />
        ))}
      </ModelPart>
      <ModelPart name="Root" color="root">
        <Root angle={38} length={3.0} width={2.0} height={2.0} />
        <Root angle={84} length={3.4} width={1.9} height={1.8} />
        <Root angle={132} length={2.7} width={2.1} height={2.1} />
        <Root angle={178} length={3.1} width={1.9} height={1.9} />
        <Root angle={226} length={3.3} width={2.1} height={2.2} />
        <Root angle={276} length={2.6} width={1.8} height={1.7} />
        <Root angle={324} length={3.1} width={2.0} height={1.9} />
        <Block size={[3, 0.5, 3]} at={[-8.75, 0, 1.25]} standing top={0.55} bevel={0.14} turn={[0, 35, 0]} />
      </ModelPart>

      <ModelPart name="Gum" color="gum">
        <Block size={[6.9, 0.1, 6.0]} at={[0, SPLIT_Y + 0.02, 0]} bevel={0.03} />
      </ModelPart>
      <ModelPart name="Throat" color="throat">
        <Block size={[5.9, 2.8, 2]} at={[0, SPLIT_Y, -2.1]} standing bevel={0.1} />
      </ModelPart>
      <ModelPart name="Tongue" color="tongue">
        <Block size={[3.1, 0.5, 2.8]} at={[0, 4.68, -0.5]} bevel={0.17} />
        <Block size={[2.7, 0.44, 2.2]} at={[0.25, 4.64, 1.8]} bevel={0.16} />
        <Block size={[1.3, 0.36, 1.1]} at={[1.45, 4.58, 3.1]} bevel={0.13} turn={[12, 0, 0]} />
        <Block size={[1.3, 0.95, 0.32]} at={[1.58, 4.02, 3.5]} bevel={0.12} turn={[-5, 0, -5]} />
        <Block size={[0.95, 0.42, 0.28]} at={[1.54, 3.36, 3.6]} bevel={0.13} turn={[-5, 0, -5]} />
      </ModelPart>
      <ModelPart name="Teeth" color="bone">
        {[[-3.05, 1.05], [-1.85, 1.35], [-0.65, 0.95], [0.55, 1.2], [2.95, 1.1]].map(([x, length]) => (
          <Tooth key={x} width={1.02} length={length} depth={0.72} at={[x, SPLIT_Y, 2.92]} />
        ))}
        {[-1, 1].map((side) => [1.5, -0.1].map((z, i) => (
          <Tooth key={`${side}${z}`} width={0.82} length={0.92 - i * 0.14} depth={0.9} at={[side * 3.3, SPLIT_Y, z]} />
        )))}
      </ModelPart>

      <ModelPart name="Collar" color="ironDark">
        <Block size={[2 * (trunkX(2.35) + 0.24), 0.92, 0.34]} at={[0, 2.35, trunkZ(2.35) + 0.12]} bevel={0.08} />
        <Block size={[2 * (trunkX(2.35) + 0.24), 0.92, 0.34]} at={[0, 2.35, -trunkZ(2.35) - 0.12]} bevel={0.08} />
        <Block size={[0.34, 0.92, 2 * (trunkZ(2.35) + 0.24)]} at={[trunkX(2.35) + 0.12, 2.35, 0]} bevel={0.08} />
        <Block size={[0.34, 0.92, 2 * (trunkZ(2.35) + 0.24)]} at={[-trunkX(2.35) - 0.12, 2.35, 0]} bevel={0.08} />
        <Block size={[1.32, 0.34, 1.32]} at={[-8.68, 2.55, 1.25]} bevel={0.05} turn={[0, 20, -4]} top={0.97} />
      </ModelPart>
      <ModelPart name="Tag" color="brass">
        <Prism sides={8} radius={0.17} height={0.1} at={[-2.1, 1.82, trunkZ(1.8) + 0.3]} turn={[90, 0, 0]} bevel={0.02} />
        <Block size={[1.05, 1.1, 0.12]} at={[-2.1, 1.2, trunkZ(1.2) + 0.32]} bevel={0.12} top={0.92} />
      </ModelPart>
      <ModelPart name="Chain" color="iron">
        <Chain from={[-trunkX(2.35) - 0.5, 2.3, 0.6]} to={[-8.1, 2.5, 1.2]} links={6} sag={1.05} width={0.62} thickness={0.18} />
        {/* Rivets on the collar. */}
        {[-3.1, -1.05, 1.05, 3.1].map((x) => (
          <Fragment key={x}>
            <Block size={[0.34, 0.34, 0.14]} at={[x, 2.35, trunkZ(2.35) + 0.32]} bevel={0} />
            <Block size={[0.34, 0.34, 0.14]} at={[x, 2.35, -trunkZ(2.35) - 0.32]} bevel={0} />
          </Fragment>
        ))}
        {[-2.6, 0, 2.6].map((z) => (
          <Fragment key={z}>
            <Block size={[0.14, 0.34, 0.34]} at={[trunkX(2.35) + 0.32, 2.35, z]} bevel={0} />
            <Block size={[0.14, 0.34, 0.34]} at={[-trunkX(2.35) - 0.32, 2.35, z]} bevel={0} />
          </Fragment>
        ))}
      </ModelPart>

      {/* The lid is the whole top of the stump. It lifts on a hinge at the back. */}
      <MovingGroup
        name="Lid"
        hinge={HINGE}
        angle={chomping ? -MOUTH_OPENS * 0.5 : -MOUTH_OPENS * mouth}
        swing={chomping ? MOUTH_OPENS * 0.44 : 0}
        speed={chomping ? 0.8 : 0}
      >
        <ModelPart name="Lid" color="barkLight">
          <Corners
            bevel={0.3}
            points={between(
              (sx, sz) => [sx * lidX(LID_Y), LID_Y, lidMiddleZ(LID_Y) + sz * lidZ(LID_Y)],
              (sx, sz) => {
                const x = sx * lidX(TOP_Y) + 0.1, z = sz * lidZ(TOP_Y) + lidMiddleZ(TOP_Y);
                return [x, cutY(x, z), z];
              },
            )}
          />
        </ModelPart>
        <ModelPart name="LidRidge" color="barkDark">
          {LID_RIDGES.map(([side, u, y0, y1, w]) => (
            <Corners key={`${side}${u}`} bevel={0.08} points={ridgePoints(side, u, y0, y1, w, 0.2, lidX, lidZ, lidMiddleZ)} />
          ))}
          {/* The brows and the twig are the same dark bark. */}
          <Block size={[2.9, 0.66, 0.9]} at={[-1.75, 8.45, faceZ(8.45) + 0.28]} turn={[-FACE_SLANT, 0, -15]} bevel={0.14} />
          <Block size={[2.3, 0.58, 0.82]} at={[1.92, 8.42, faceZ(8.42) + 0.26]} turn={[-FACE_SLANT, 0, 19]} bevel={0.13} />
          <Place at={[2.35, cutY(2.35, 1.3) - 0.2, 1.3]} turn={[8, 0, -20]}>
            <Block size={[0.72, 2.5, 0.72]} standing top={0.55} bevel={0.1} />
            <Block size={[0.4, 1.2, 0.4]} at={[0.12, 1.3, 0]} standing top={0.5} bevel={0.06} turn={[0, 0, -48]} />
          </Place>
        </ModelPart>
        <Place at={[0.1, cutY(0.1, -0.1), -0.1]} turn={CUT_TURN}>
          <ModelPart name="Rings" color="innerWood">
            <Block size={[6.1, 0.12, 5.4]} at={[0, 0, 0]} bevel={0.05} />
          </ModelPart>
          <ModelPart name="RingLines" color="rings">
            <RingLines />
          </ModelPart>
        </Place>

        <ModelPart name="LidGum" color="gum">
          <Block size={[7.2, 0.1, 6.5]} at={[0, LID_Y - 0.03, 0.12]} bevel={0.03} />
          {EYES.map((eye) => (
            <EyeLayer key={eye.x} {...eye} layer="socket" />
          ))}
          <Prism sides={6} radius={0.42} height={0.16} at={[0.05, 5.72, faceZ(5.72) + 0.03]} turn={[90 - FACE_SLANT, 0, 0]} bevel={0.04} />
        </ModelPart>
        <ModelPart name="Fangs" color="bone">
          {[[-3.42, 1.0], [-2.38, 1.95], [-1.3, 1.1], [-0.18, 1.2], [2.1, 1.8], [3.3, 0.95]].map(([x, length]) => (
            <Tooth key={x} width={x === -2.38 || x === 2.1 ? 1.24 : 0.98} length={length} depth={0.64} at={[x, LID_Y, 3.58]} down />
          ))}
          {[-1, 1].map((side) => [2.0, 0.3].map((z, i) => (
            <Tooth key={`${side}${z}`} width={0.78} length={0.84 - i * 0.14} depth={0.86} at={[side * 3.62, LID_Y, z]} down />
          )))}
        </ModelPart>

        <ModelPart name="Eye" color="amber" glow={0.28}>
          {EYES.map((eye) => (
            <EyeLayer key={eye.x} {...eye} layer="eye" />
          ))}
        </ModelPart>
        <MovingGroup name="Pupils" sway={[0.14, 0, 0]} speed={chomping ? 0 : 0.18}>
          <ModelPart name="Pupil" color="throat">
            {EYES.map((eye) => (
              <EyeLayer key={eye.x} {...eye} layer="pupil" />
            ))}
          </ModelPart>
          <ModelPart name="Glint" color="bone">
            {EYES.map((eye) => (
              <EyeLayer key={eye.x} {...eye} layer="glint" />
            ))}
          </ModelPart>
        </MovingGroup>

        <ModelPart name="Moss" color="moss">
          <Place at={[-1.6, cutY(-1.6, -1.4), -1.4]} turn={CUT_TURN}>
            <Block size={[2.6, 0.28, 2.3]} at={[0, 0.14, 0]} bevel={0.1} turn={[0, 14, 0]} />
            <Block size={[1.5, 0.24, 1.4]} at={[1.5, 0.12, 0.9]} bevel={0.09} turn={[0, 30, 0]} />
          </Place>
          <Block size={[0.3, 1.5, 1.8]} at={[-lidX(7.6) - 0.1, 7.6, -1.2]} bevel={0.1} turn={[0, 0, 8]} top={[1, 0.8]} />
          <Block size={[1.9, 1.1, 0.3]} at={[-1.8, 7.9, lidMiddleZ(7.9) - lidZ(7.9) - 0.08]} bevel={0.1} turn={[-10, 0, 0]} />
          {/* The leaves on the twig. */}
          <Place at={[2.35, cutY(2.35, 1.3) - 0.2, 1.3]} turn={[8, 0, -20]}>
            <Block size={[0.82, 0.32, 0.62]} at={[0.1, 2.75, 0]} bevel={0.08} turn={[0, 24, 18]} />
            <Block size={[0.7, 0.28, 0.54]} at={[-0.34, 2.45, 0.28]} bevel={0.07} turn={[20, 70, -24]} />
            <Block size={[0.76, 0.3, 0.56]} at={[1.08, 2.25, 0.06]} bevel={0.08} turn={[-8, -10, -30]} />
          </Place>
        </ModelPart>
      </MovingGroup>
    </>
  );
}

/**
 * Gnawbert, the game's mascot: a chained stump mimic that eats logs at the sawmill. The whole top
 * of the stump is its lid, which lifts on a hinge at the back.
 *
 * @category Models
 */
export function Gnawbert(props: GnawbertProps): JSX.Element {
  const { mouth = 0.25, chomping = false, ...stage } = props;
  return (
    <ModelStage name="Gnawbert" label="Gnawbert, a chained tree stump with a toothy mouth and amber eyes" {...stage}>
      <Pieces mouth={mouth} chomping={chomping} />
    </ModelStage>
  );
}
