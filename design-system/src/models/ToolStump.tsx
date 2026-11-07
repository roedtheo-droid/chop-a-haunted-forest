import { Block } from "../shapes/Block";
import { Corners } from "../shapes/Corners";
import { Prism } from "../shapes/Prism";
import { lerp, rad } from "../core/math";
import type { Vec3 } from "../core/math";
import { ModelStage } from "../stage/ModelStage";
import type { ModelStageProps } from "../stage/ModelStage";
import { ModelPart } from "../structure/ModelPart";
import { Place } from "../structure/Place";
import { GroundRoot, HangingLantern, boxPoints } from "./pieces";

export interface ToolStumpProps extends Pick<ModelStageProps, "width" | "height" | "yaw" | "pitch" | "spin" | "person" | "ground" | "background" | "distance" | "target" | "style"> {
  /**
   * Shows an axe floating above the stump and a price plate on its front, the way the game dresses
   * it. They're only on the board: the game puts the real tool and plate there. On by default.
   */
  dressed?: boolean;
}

// The sizes it's built from, in studs. +Z is its front, and it stands on y = 0.
const HEIGHT = 3.4;
const POST_Z = -3.25;
const POST_TOP = 13.2;
const LANTERN: Vec3 = [0, 12.35, 0];

const radius = (y: number) => lerp(2.95, 2.55, y / HEIGHT);

/** A raised strip of bark on the stump's side, at `angle` degrees (0 is the front). */
function BarkRidge({ angle, y0, y1, width }: { angle: number; y0: number; y1: number; width: number }) {
  const a = rad(angle);
  const sin = Math.sin(a), cos = Math.cos(a);
  return (
    <Corners
      bevel={0.07}
      points={boxPoints((sx, sy, sz) => {
        const y = sy > 0 ? y1 : y0;
        const r = radius(y) + (sz > 0 ? 0.14 : -0.3);
        const across = (sx * width) / 2;
        return [sin * r + cos * across, y, cos * r - sin * across];
      })}
    />
  );
}

const RIDGES: [number, number, number, number][] = [
  [90, 0.3, 3.2, 0.62], [125, 0.2, 2.4, 0.52], [160, 0.4, 3.3, 0.66], [195, 0.2, 3, 0.5],
  [230, 0.3, 3.3, 0.6], [270, 0.2, 2.6, 0.56], [305, 0.3, 3.2, 0.62], [40, 0.2, 1.1, 0.5], [320, 0.2, 1, 0.5],
];

const ROOTS: [number, number, number, number][] = [
  [28, 2.2, 1.7, 1.5], [82, 2.5, 1.5, 1.4], [138, 2.1, 1.6, 1.6], [226, 2.3, 1.7, 1.5], [282, 2.5, 1.5, 1.5], [334, 2, 1.6, 1.4],
];

/** Rings on the cut top: each ring is a low step on the one before it. */
function CutTop() {
  const y = HEIGHT + 0.05;
  return (
    <>
      <ModelPart name="Rings" color="innerWood">
        <Prism sides={10} radius={2.42} height={0.12} at={[0, y, 0]} bevel={0.04} />
        <Prism sides={10} radius={1.62} height={0.03} at={[0, y + 0.09, 0]} bevel={0} />
        <Prism sides={10} radius={0.86} height={0.03} at={[0, y + 0.13, 0]} bevel={0} />
      </ModelPart>
      <ModelPart name="RingLines" color="rings">
        <Prism sides={10} radius={1.82} height={0.03} at={[0, y + 0.07, 0]} bevel={0} />
        <Prism sides={10} radius={1.06} height={0.03} at={[0, y + 0.11, 0]} bevel={0} />
        <Prism sides={10} radius={0.38} height={0.03} at={[0, y + 0.15, 0]} bevel={0} />
      </ModelPart>
    </>
  );
}

function Pieces({ dressed }: { dressed: boolean }) {
  return (
    <>
      <ModelPart name="Pivot" color="ironDark" hidden>
        <Block size={[0.2, 0.2, 0.2]} at={[0, 0.1, 0]} bevel={0} />
      </ModelPart>

      <ModelPart name="Trunk" color="bark">
        <Prism sides={10} radius={radius(0)} height={HEIGHT} at={[0, HEIGHT / 2, 0]} top={radius(HEIGHT) / radius(0)} bevel={0.2} />
      </ModelPart>
      <ModelPart name="Ridge" color="barkDark">
        {RIDGES.map(([angle, y0, y1, width]) => (
          <BarkRidge key={angle} angle={angle} y0={y0} y1={y1} width={width} />
        ))}
      </ModelPart>
      <ModelPart name="Root" color="root">
        {ROOTS.map(([angle, length, width, height]) => (
          <GroundRoot key={angle} angle={angle} reach={2.45} length={length} width={width} height={height} />
        ))}
      </ModelPart>
      <CutTop />
      <ModelPart name="Moss" color="moss">
        <Block size={[1.5, 0.26, 1.1]} at={[-1.55, HEIGHT + 0.1, 0.95]} turn={[0, 28, 0]} bevel={0.09} />
        <Block size={[0.9, 0.22, 0.8]} at={[-0.8, HEIGHT + 0.1, 1.55]} turn={[0, 62, 0]} bevel={0.08} />
        <Block size={[0.32, 1.1, 1.3]} at={[-radius(2.9) + 0.02, 2.75, 0.85]} turn={[0, 0, 7]} bevel={0.09} top={[1, 0.8]} />
      </ModelPart>

      {/* A post behind the stump holds the lantern above the tool. */}
      <ModelPart name="Post" color="barkDark">
        <Block size={[0.95, POST_TOP, 0.95]} at={[0, 0, POST_Z]} standing top={0.72} shift={[0.06, 0.06]} bevel={0.14} />
      </ModelPart>
      <ModelPart name="Arm" color="barkDark">
        <Block size={[0.62, 0.62, 3.95]} at={[0.04, POST_TOP - 0.45, -1.5]} bevel={0.1} />
        <Block size={[0.42, 0.42, 2.55]} at={[0.04, POST_TOP - 1.42, -2.25]} turn={[-46, 0, 0]} bevel={0.06} />
      </ModelPart>
      <HangingLantern at={LANTERN} drop={0.5} />
      <ModelPart name="Iron" color="ironDark">
        {/* The band that ties the post to the stump, and the hook the lantern hangs on. */}
        <Block size={[1.3, 0.34, 1.3]} at={[0.03, 2.45, POST_Z]} bevel={0.05} />
        <Block size={[0.22, 0.34, 0.22]} at={[0, LANTERN[1] + 0.12, LANTERN[2]]} bevel={0} />
      </ModelPart>

      {dressed && (
        <>
          {/* The game's own price plate and tool go here. */}
          <ModelPart name="ShownPlate" color="edge" stage>
            <Place at={[0, 1.75, radius(1.75) + 0.1]} turn={[-7, 0, 0]}>
              <Block size={[4.2, 2.5, 0.2]} bevel={0.05} />
            </Place>
          </ModelPart>
          <ModelPart name="ShownWords" color="brass" stage>
            <Place at={[0, 1.75, radius(1.75) + 0.1]} turn={[-7, 0, 0]}>
              <Block size={[2.5, 0.42, 0.06]} at={[0, 0.62, 0.11]} bevel={0} />
              <Prism sides={8} radius={0.4} height={0.06} at={[-1, -0.42, 0.11]} turn={[90, 0, 0]} bevel={0} />
              <Block size={[1.3, 0.62, 0.06]} at={[0.25, -0.42, 0.11]} bevel={0} />
            </Place>
          </ModelPart>
          <ModelPart name="ShownHandle" color="plank" stage>
            <Place at={[0, 6.9, 0]} turn={[0, 28, 0]}>
              <Block size={[0.42, 5.1, 0.42]} bevel={0.07} />
            </Place>
          </ModelPart>
          <ModelPart name="ShownHead" color="iron" stage>
            <Place at={[0, 6.9, 0]} turn={[0, 28, 0]}>
              <Block size={[2.2, 1.5, 0.3]} at={[0.68, 1.9, 0]} bevel={0.06} top={[0.7, 1]} />
            </Place>
          </ModelPart>
        </>
      )}
    </>
  );
}

/**
 * A tree stump that shows one tool in the Tool Shed, with a lantern hanging over it from a post
 * behind. The tool floats above the stump and turns slowly, and the price plate goes on its front.
 *
 * @category Models
 */
export function ToolStump(props: ToolStumpProps): JSX.Element {
  const { dressed = true, ...stage } = props;
  return (
    <ModelStage name="ToolStump" label="A tree stump under a hanging lantern, with a tool floating above it" {...stage}>
      <Pieces dressed={dressed} />
    </ModelStage>
  );
}
