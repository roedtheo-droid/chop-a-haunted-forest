// Small helpers that several finished models share. They're plain functions with no hooks, like
// everything inside a stage. The library doesn't export them.

import { Block } from "../shapes/Block";
import { Chain } from "../shapes/Chain";
import { Corners } from "../shapes/Corners";
import { Prism } from "../shapes/Prism";
import type { Vec3 } from "../core/math";
import { ModelPart } from "../structure/ModelPart";
import { Place } from "../structure/Place";

/** Eight corners of a box, from a function of its three sides: each is -1 or 1. */
export function boxPoints(point: (sx: number, sy: number, sz: number) => Vec3): Vec3[] {
  const points: Vec3[] = [];
  for (let i = 0; i < 8; i++) {
    points.push(point(i & 1 ? 1 : -1, i & 2 ? 1 : -1, i & 4 ? 1 : -1));
  }
  return points;
}

/** A root that hugs the ground, spreading out at `angle` degrees (0 is the front). */
export function GroundRoot({ angle, reach, length, width, height }: { angle: number; reach: number; length: number; width: number; height: number }) {
  const a = (angle * Math.PI) / 180;
  return (
    <Place at={[Math.sin(a) * reach, 0, Math.cos(a) * reach]} turn={[0, angle, 0]}>
      <Corners
        bevel={0.1}
        points={boxPoints((sx, sy, sz) => {
          if (sz < 0) return [(sx * width) / 2, sy > 0 ? height : 0, 0];
          return [sx * width * 0.2, sy > 0 ? 0.2 : 0, length];
        })}
      />
    </Place>
  );
}

/**
 * A lantern hanging on a short chain, with its top hook at `at`. The parts are called Chain, Iron
 * and Lamp. `drop` is how long the chain is. The lantern itself is about 2 studs tall.
 */
export function HangingLantern({ at, drop = 0.8 }: { at: Vec3; drop?: number }) {
  const [x, y, z] = at;
  const top = y - drop;
  return (
    <>
      <ModelPart name="Chain" color="iron">
        <Chain from={[x, y, z]} to={[x, top + 0.1, z]} links={Math.max(2, Math.round(drop / 0.42))} width={0.32} thickness={0.09} />
      </ModelPart>
      <ModelPart name="Iron" color="ironDark">
        <Prism sides={6} radius={0.78} height={0.42} at={[x, top - 0.28, z]} top={0.42} bevel={0.04} />
        <Prism sides={6} radius={0.72} height={0.2} at={[x, top - 1.86, z]} bevel={0.04} />
        {[-1, 1].map((sx) => [-1, 1].map((sz) => (
          <Block key={`${sx}${sz}`} size={[0.11, 1.42, 0.11]} at={[x + sx * 0.46, top - 1.08, z + sz * 0.46]} bevel={0} />
        )))}
      </ModelPart>
      <ModelPart name="Lamp" color="amber" glow={0.6}>
        <Block size={[0.82, 1.3, 0.82]} at={[x, top - 1.08, z]} bevel={0.08} />
      </ModelPart>
    </>
  );
}

/** A ring in the XY plane, made of short bars. For wheels, spectacles and drawn circles. */
export function BarRing({ radius, bars = 12, width, depth, at = [0, 0, 0], start = 0 }: { radius: number; bars?: number; width: number; depth: number; at?: Vec3; start?: number }) {
  const list = [];
  const step = (Math.PI * 2) / bars;
  const bar = 2 * radius * Math.tan(step / 2) + width * 0.3;
  for (let i = 0; i < bars; i++) {
    const a = start + i * step;
    list.push(
      <Block
        key={i}
        size={[bar, width, depth]}
        at={[at[0] + Math.cos(a) * radius, at[1] + Math.sin(a) * radius, at[2]]}
        turn={[0, 0, (a * 180) / Math.PI + 90]}
        bevel={0}
      />,
    );
  }
  return <>{list}</>;
}
