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
import { BarRing, HangingLantern, boxPoints } from "./pieces";

export interface PeddlerCartProps extends Pick<ModelStageProps, "width" | "height" | "yaw" | "pitch" | "spin" | "person" | "ground" | "background" | "distance" | "target" | "style"> {
  /** Shows bars where the sign's word goes. They're only on the board: the game writes the real word. On by default. */
  words?: boolean;
}

// The sizes it's built from, in studs. +Z is the side that sells, and it stands on y = 0.
const LENGTH = 9.2; // along X, without the handles
const DEPTH = 4.6;
const AXLE_Y = 2.2;
const WHEEL = 2.2;
const WHEEL_Z = 2.95;
const BED_Y = 2.4; // the top of the cart's floor
const ROOF_BACK = { y: 9.5, z: -2.75 };
const ROOF_FRONT = { y: 7.25, z: 3.75 };
const POST_BOTTOM = BED_Y - 0.5; // the roof's posts stop under the floor: the cart stands on its wheels
const STRIPES = 9;
const ROOF_X = 5.2;

const roofY = (z: number) => lerp(ROOF_BACK.y, ROOF_FRONT.y, (z - ROOF_BACK.z) / (ROOF_FRONT.z - ROOF_BACK.z));

function Wheel({ z }: { z: number }) {
  const spokes = [];
  for (let i = 0; i < 6; i++) {
    const a = (i * Math.PI) / 3 + 0.26;
    spokes.push(
      <Block key={i} size={[WHEEL - 0.4, 0.24, 0.24]} at={[Math.cos(a) * WHEEL * 0.48, AXLE_Y + Math.sin(a) * WHEEL * 0.48, z]} turn={[0, 0, (a * 180) / Math.PI]} bevel={0} />,
    );
  }
  return (
    <>
      <ModelPart name="Rim" color="edge">
        <BarRing radius={WHEEL - 0.2} bars={12} width={0.4} depth={0.42} at={[0, AXLE_Y, z]} />
      </ModelPart>
      <ModelPart name="Spoke" color="plankDark">
        {spokes}
      </ModelPart>
      <ModelPart name="Hub" color="ironDark">
        <Prism sides={8} radius={0.5} height={0.74} at={[0, AXLE_Y, z]} turn={[90, 0, 0]} bevel={0.08} />
      </ModelPart>
    </>
  );
}

/** One side of the cart: planks on top of each other, from `y0` up. */
function PlankSide({ z, y0, count }: { z: number; y0: number; count: number }) {
  const list = [];
  for (let i = 0; i < count; i++) {
    list.push(<Block key={i} size={[LENGTH, 0.5, 0.2]} at={[0, y0 + 0.27 + i * 0.56, z]} bevel={0.04} />);
  }
  return <>{list}</>;
}

function PlankEnd({ x, y0, count }: { x: number; y0: number; count: number }) {
  const list = [];
  for (let i = 0; i < count; i++) {
    list.push(<Block key={i} size={[0.2, 0.5, DEPTH]} at={[x, y0 + 0.27 + i * 0.56, 0]} bevel={0.04} />);
  }
  return <>{list}</>;
}

/** One stripe of the canvas roof, with a tooth hanging off its front edge. */
function Stripe({ index }: { index: number }) {
  const width = (ROOF_X * 2) / STRIPES;
  const x0 = -ROOF_X + index * width;
  return (
    <>
      <Corners
        bevel={0.03}
        points={boxPoints((sx, sy, sz) => {
          const z = sz > 0 ? ROOF_FRONT.z : ROOF_BACK.z;
          return [x0 + (sx > 0 ? width : 0), roofY(z) + (sy > 0 ? 0.14 : 0), z];
        })}
      />
      <Tooth width={width * 0.98} length={index % 2 ? 0.72 : 0.92} depth={0.14} tip={0.3} at={[x0 + width / 2, ROOF_FRONT.y + 0.08, ROOF_FRONT.z]} down />
    </>
  );
}

function Roof() {
  const stripes = [0, 1, 2, 3, 4, 5, 6, 7, 8];
  return (
    <>
      <ModelPart name="Canvas" color="moss">
        {stripes.filter((i) => i % 2 === 0).map((i) => <Stripe key={i} index={i} />)}
      </ModelPart>
      <ModelPart name="CanvasLight" color="paper">
        {stripes.filter((i) => i % 2 === 1).map((i) => <Stripe key={i} index={i} />)}
      </ModelPart>
    </>
  );
}

/** A fat sack tied at the neck: the Infinite Bag, which never gets full. */
function FatSack({ at }: { at: Vec3 }) {
  const [x, y, z] = at;
  return (
    <>
      <ModelPart name="Sack" color="rings">
        <Prism sides={8} radius={1.28} height={0.8} at={[x, y + 0.4, z]} top={1.1} bevel={0.14} />
        <Prism sides={8} radius={1.41} height={1.05} at={[x, y + 1.3, z]} top={0.76} bevel={0.14} />
        <Prism sides={8} radius={1.05} height={0.42} at={[x, y + 2.0, z]} top={0.56} bevel={0.06} />
        <Prism sides={7} radius={0.5} height={0.4} at={[x, y + 2.46, z]} top={1.5} bevel={0.05} />
      </ModelPart>
      <ModelPart name="Rope" color="plankDark">
        <Prism sides={8} radius={0.62} height={0.16} at={[x, y + 2.24, z]} bevel={0.03} />
      </ModelPart>
      {/* Two rings side by side on its belly, like an infinity sign. */}
      <ModelPart name="Stitch" color="brass">
        <BarRing radius={0.28} bars={8} width={0.08} depth={0.06} at={[x - 0.27, y + 1.2, z + 1.31]} start={Math.PI / 8} />
        <BarRing radius={0.28} bars={8} width={0.08} depth={0.06} at={[x + 0.27, y + 1.2, z + 1.31]} start={Math.PI / 8} />
      </ModelPart>
    </>
  );
}

/** Two equal stacks of coins: 2X COINS. */
function CoinStacks({ at }: { at: Vec3 }) {
  const [x, y, z] = at;
  const coins = [];
  for (const [side, count] of [[-0.48, 6], [0.48, 6]]) {
    for (let i = 0; i < count; i++) {
      coins.push(<Prism key={`${side}${i}`} sides={8} radius={0.42} height={0.15} at={[x + side + (i % 2 ? 0.03 : -0.03), y + 0.08 + i * 0.16, z + (i % 3) * 0.02]} bevel={0.03} />);
    }
  }
  return <ModelPart name="Coin" color="brass">{coins}</ModelPart>;
}

function Crate({ at, size }: { at: Vec3; size: number }) {
  const [x, y, z] = at;
  const s = size / 2;
  return (
    <>
      <ModelPart name="Crate" color="plank">
        <Block size={[size, size, size]} at={[x, y, z]} standing bevel={0.06} />
      </ModelPart>
      <ModelPart name="Trim" color="plankDark">
        {[-1, 1].map((sy) => (
          <Fragment key={sy}>
            <Block size={[size + 0.1, 0.22, 0.14]} at={[x, y + s + sy * (s - 0.11), z + s + 0.02]} bevel={0} />
            <Block size={[0.14, 0.22, size + 0.1]} at={[x + s + 0.02, y + s + sy * (s - 0.11), z]} bevel={0} />
            <Block size={[0.14, 0.22, size + 0.1]} at={[x - s - 0.02, y + s + sy * (s - 0.11), z]} bevel={0} />
          </Fragment>
        ))}
        <Block size={[size * 1.2, 0.22, 0.12]} at={[x, y + s, z + s + 0.02]} turn={[0, 0, 45]} bevel={0} />
      </ModelPart>
    </>
  );
}

function Pieces({ words }: { words: boolean }) {
  const postTop = (z: number) => roofY(z) + 0.02;
  return (
    <>
      <ModelPart name="Pivot" color="ironDark" hidden>
        <Block size={[0.2, 0.2, 0.2]} at={[0, 0.1, 0]} bevel={0} />
      </ModelPart>

      {/* The wheels and the axle. */}
      <Wheel z={WHEEL_Z} />
      <Wheel z={-WHEEL_Z} />
      <ModelPart name="Hub" color="ironDark">
        <Block size={[0.34, 0.34, WHEEL_Z * 2]} at={[0, AXLE_Y, 0]} bevel={0} />
      </ModelPart>

      {/* The cart itself. */}
      <ModelPart name="Deck" color="plankDark">
        <Block size={[LENGTH + 0.2, 0.34, DEPTH + 0.2]} at={[0, BED_Y - 0.17, 0]} bevel={0.05} />
      </ModelPart>
      <ModelPart name="Board" color="plank">
        <PlankSide z={DEPTH / 2} y0={BED_Y - 0.1} count={2} />
        <PlankSide z={-DEPTH / 2} y0={BED_Y - 0.1} count={5} />
        <PlankEnd x={LENGTH / 2} y0={BED_Y - 0.1} count={3} />
        <PlankEnd x={-LENGTH / 2} y0={BED_Y - 0.1} count={3} />
      </ModelPart>
      <ModelPart name="Post" color="plankDark">
        {[-1, 1].map((side) => (
          <Fragment key={side}>
            <Block size={[0.46, postTop(DEPTH / 2) - POST_BOTTOM, 0.46]} at={[(side * LENGTH) / 2, POST_BOTTOM, DEPTH / 2]} standing top={0.9} bevel={0.06} />
            <Block size={[0.46, postTop(-DEPTH / 2) - POST_BOTTOM, 0.46]} at={[(side * LENGTH) / 2, POST_BOTTOM, -DEPTH / 2]} standing top={0.9} bevel={0.06} />
          </Fragment>
        ))}
        {/* The beams that hold the canvas, and that things hang from. */}
        <Block size={[LENGTH + 0.6, 0.36, 0.36]} at={[0, postTop(DEPTH / 2) - 0.3, DEPTH / 2]} bevel={0.05} />
        <Block size={[LENGTH + 0.6, 0.36, 0.36]} at={[0, postTop(-DEPTH / 2) - 0.3, -DEPTH / 2]} bevel={0.05} />
      </ModelPart>

      {/* A prop on the right, so it stands level. */}
      <ModelPart name="Leg" color="plankDark">
        {[-1.6, 1.6].map((z) => (
          <Block key={z} size={[0.46, BED_Y - 0.2, 0.46]} at={[3.9, 0, z]} standing top={0.9} shift={[-0.16, 0]} bevel={0.06} />
        ))}
        <Block size={[0.4, 0.34, 3.6]} at={[3.84, 1.05, 0]} bevel={0.05} />
      </ModelPart>

      {/* Two handles on the left, resting on a little log. */}
      <ModelPart name="Shaft" color="plankDark">
        {[-1.55, 1.55].map((z) => (
          <Corners
            key={z}
            bevel={0.05}
            points={boxPoints((sx, sy, sz) => {
              const x = sx > 0 ? -LENGTH / 2 + 0.3 : -8.1;
              const y = sx > 0 ? BED_Y - 0.25 : 1.1;
              return [x, y + sy * 0.16, z + sz * 0.17];
            })}
          />
        ))}
        <Block size={[0.3, 0.3, 3.6]} at={[-7.9, 1.2, 0]} bevel={0.05} />
      </ModelPart>
      <ModelPart name="Log" color="bark">
        <Prism sides={8} radius={0.48} height={3.9} at={[-7.2, 0.46, 0]} turn={[90, 0, 0]} bevel={0.06} />
      </ModelPart>
      <ModelPart name="Rings" color="innerWood">
        <Prism sides={8} radius={0.38} height={0.04} at={[-7.2, 0.46, 1.96]} turn={[90, 0, 0]} bevel={0} />
      </ModelPart>

      <Roof />

      {/* What's for sale. */}
      <FatSack at={[-2.7, BED_Y, 0.1]} />
      <Crate at={[0.45, BED_Y, 0.15]} size={1.9} />
      <CoinStacks at={[0.45, BED_Y + 1.9, 0.15]} />
      <Crate at={[2.95, BED_Y, -0.5]} size={2.4} />
      <Crate at={[3.0, BED_Y + 2.4, -0.55]} size={1.2} />

      {/* The sign, on chains from the front beam. */}
      <ModelPart name="Chain" color="iron">
        <Chain from={[-1.6, postTop(DEPTH / 2) - 0.45, DEPTH / 2 + 0.02]} to={[-1.6, 6.62, DEPTH / 2 + 0.02]} links={2} width={0.32} thickness={0.09} />
        <Chain from={[1.6, postTop(DEPTH / 2) - 0.45, DEPTH / 2 + 0.02]} to={[1.6, 6.62, DEPTH / 2 + 0.02]} links={2} width={0.32} thickness={0.09} />
      </ModelPart>
      <ModelPart name="Sign" color="plank">
        <Block size={[4.9, 1.5, 0.22]} at={[0, 5.88, DEPTH / 2 + 0.02]} bevel={0.06} />
      </ModelPart>
      {words && (
        <ModelPart name="ShownWords" color="edge" stage>
          <Block size={[3.8, 0.72, 0.03]} at={[0, 5.88, DEPTH / 2 + 0.14]} bevel={0} />
        </ModelPart>
      )}

      <HangingLantern at={[3.55, postTop(DEPTH / 2) - 0.45, DEPTH / 2 + 0.02]} drop={0.3} />

      {/* A little bell the peddler rings. */}
      <ModelPart name="Rope" color="plankDark">
        <Block size={[0.12, 0.62, 0.12]} at={[-3.55, postTop(DEPTH / 2) - 0.75, DEPTH / 2 + 0.02]} bevel={0} />
      </ModelPart>
      <ModelPart name="Bell" color="brass">
        <Prism sides={8} radius={0.58} height={0.86} at={[-3.55, postTop(DEPTH / 2) - 1.45, DEPTH / 2 + 0.02]} top={0.56} bevel={0.06} />
      </ModelPart>
      <ModelPart name="Bell" color="brass">
        <Prism sides={6} radius={0.14} height={0.18} at={[-3.55, postTop(DEPTH / 2) - 1.96, DEPTH / 2 + 0.02]} bevel={0.02} />
      </ModelPart>
    </>
  );
}

/**
 * A peddler's hand cart with a striped canvas roof whose edge looks like teeth. It stands beside
 * every sell pad and opens the SHOP menu. On it: a fat sack, two stacks of coins, and crates.
 *
 * @category Models
 */
export function PeddlerCart(props: PeddlerCartProps): JSX.Element {
  const { words = true, ...stage } = props;
  return (
    <ModelStage name="PeddlerCart" label="A wooden hand cart with a striped canvas roof, a hanging sign and goods for sale" {...stage}>
      <Pieces words={words} />
    </ModelStage>
  );
}
