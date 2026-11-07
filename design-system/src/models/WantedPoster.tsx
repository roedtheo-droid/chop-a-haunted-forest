import { Fragment } from "react";
import { Block } from "../shapes/Block";
import { Corners } from "../shapes/Corners";
import { Prism } from "../shapes/Prism";
import type { Vec3 } from "../core/math";
import { ModelStage } from "../stage/ModelStage";
import type { ModelStageProps } from "../stage/ModelStage";
import { ModelPart } from "../structure/ModelPart";
import { Place } from "../structure/Place";

export type PosterSketch = "A" | "B" | "C";

export interface WantedPosterProps extends Pick<ModelStageProps, "width" | "height" | "yaw" | "pitch" | "spin" | "person" | "ground" | "background" | "distance" | "target" | "style"> {
  /** Which mimic it shows: A a grinning pine, B a stump with its mouth open, C an oak running away. */
  sketch?: PosterSketch;
  /**
   * Shows bars where the poster's words go. They're only on the board, because the game writes the
   * real words on it. On by default.
   */
  words?: boolean;
}

// In studs. It hangs flat on a wall: y = 0 is its bottom, z = 0 the wall, and +Z looks into the room.
const INK_Z = 0.11; // in front of the paper
const FACE_Z = 0.16; // in front of the ink

const SHEET: Vec3[] = [
  [-2.76, 0, 0], [2.7, 0.06, 0], [-2.82, 7.38, 0], [2.8, 7.42, 0],
  [-2.76, 0, 0.08], [2.7, 0.06, 0.08], [-2.82, 7.38, 0.08], [2.8, 7.42, 0.08],
];

/** A flat shape on the paper. `top` narrows it upward, for drawing trees and teeth. */
function Flat({ w, h, x, y, z = INK_Z, top = 1, turn = 0 }: { w: number; h: number; x: number; y: number; z?: number; top?: number; turn?: number }) {
  return <Block size={[w, h, 0.04]} at={[x, y, z]} turn={[0, 0, turn]} top={[top, 1]} bevel={0} />;
}

/** A row of flat teeth, pointing up (1) or down (-1). */
function ToothRow({ from, to, count, y, length, width, way, z }: { from: number; to: number; count: number; y: number; length: number; width: number; way: 1 | -1; z: number }) {
  const list = [];
  for (let i = 0; i < count; i++) {
    const x = count > 1 ? from + ((to - from) * i) / (count - 1) : from;
    list.push(<Flat key={i} w={width} h={length} x={x} y={y + (way * length) / 2} z={z} top={0.1} turn={way < 0 ? 180 : 0} />);
  }
  return <>{list}</>;
}

/** A flat round spot, like an eye. */
function Spot({ radius, x, y, z }: { radius: number; x: number; y: number; z: number }) {
  return <Prism sides={8} radius={radius} height={0.04} at={[x, y, z]} turn={[90, 0, 0]} bevel={0} />;
}

/** A: a pine with a jagged grin. */
function SketchA({ on }: { on: boolean }) {
  return (
    <>
      <ModelPart name="SketchA" color="ink" hidden={!on}>
        <Flat w={0.95} h={0.6} x={0} y={2.72} />
        <Flat w={4.1} h={1.5} x={0} y={3.55} top={0.42} />
        <Flat w={3.3} h={1.45} x={0} y={4.45} top={0.42} />
        <Flat w={2.4} h={1.5} x={0} y={5.25} top={0.06} />
      </ModelPart>
      <ModelPart name="SketchAFace" color="paper" hidden={!on}>
        <Flat w={0.74} h={0.26} x={-0.5} y={4.5} z={FACE_Z} turn={-20} />
        <Flat w={0.74} h={0.26} x={0.5} y={4.5} z={FACE_Z} turn={20} />
        <ToothRow from={-1} to={1} count={5} y={4} length={0.5} width={0.48} way={-1} z={FACE_Z} />
        <ToothRow from={-0.76} to={0.76} count={4} y={3.2} length={0.42} width={0.46} way={1} z={FACE_Z} />
      </ModelPart>
    </>
  );
}

/** B: a stump with its lid up, and teeth in the gap. */
function SketchB({ on }: { on: boolean }) {
  return (
    <>
      <ModelPart name="SketchB" color="ink" hidden={!on}>
        <Flat w={3.5} h={1.3} x={0} y={3.05} top={0.92} />
        <Flat w={0.9} h={0.46} x={-1.95} y={2.62} top={0.2} turn={40} />
        <Flat w={0.9} h={0.46} x={1.95} y={2.62} top={0.2} turn={-40} />
        <Place at={[-1.65, 4.12, 0]} turn={[0, 0, 15]}>
          <Flat w={3.5} h={1.2} x={1.7} y={0.6} top={0.9} />
          <ToothRow from={0.45} to={3} count={4} y={0.02} length={0.62} width={0.56} way={-1} z={INK_Z} />
        </Place>
        <ToothRow from={-1.3} to={1.3} count={5} y={3.69} length={0.46} width={0.46} way={1} z={INK_Z} />
        <Spot radius={0.2} x={-0.25} y={5} z={FACE_Z + 0.05} />
        <Spot radius={0.16} x={0.95} y={5.34} z={FACE_Z + 0.05} />
      </ModelPart>
      <ModelPart name="SketchBFace" color="paper" hidden={!on}>
        <Spot radius={0.42} x={-0.25} y={5} z={FACE_Z} />
        <Spot radius={0.34} x={0.95} y={5.34} z={FACE_Z} />
      </ModelPart>
    </>
  );
}

/** C: an oak on two root legs, running away. */
function SketchC({ on }: { on: boolean }) {
  return (
    <>
      <ModelPart name="SketchC" color="ink" hidden={!on}>
        {/* Its crown is a cloud of lumps, so it reads as a tree. */}
        <Spot radius={1.12} x={0.04} y={4.86} z={INK_Z} />
        <Spot radius={0.72} x={-1.32} y={4.56} z={INK_Z} />
        <Spot radius={0.72} x={1.38} y={4.56} z={INK_Z} />
        <Spot radius={0.72} x={-0.76} y={5.24} z={INK_Z} />
        <Spot radius={0.72} x={0.84} y={5.24} z={INK_Z} />
        <Flat w={0.8} h={1.05} x={0.06} y={3.55} top={1.35} />
        {/* One leg trails behind with its foot kicked up, and the other reaches out in front. */}
        <Flat w={0.4} h={1.2} x={-0.52} y={2.88} turn={-63} />
        <Flat w={0.34} h={0.72} x={-1.3} y={2.8} turn={51} />
        <Flat w={0.4} h={1.08} x={0.58} y={2.8} turn={49} />
        <Flat w={0.8} h={0.26} x={1.24} y={2.42} />
        {/* The lines behind it that say it's running. */}
        <Flat w={0.5} h={0.09} x={-2.08} y={3.86} />
        <Flat w={0.34} h={0.09} x={-2.16} y={3.46} />
        <Flat w={0.5} h={0.09} x={-2.08} y={3.06} />
        <Spot radius={0.17} x={-0.46} y={5} z={FACE_Z + 0.05} />
        <Spot radius={0.17} x={0.34} y={5} z={FACE_Z + 0.05} />
      </ModelPart>
      <ModelPart name="SketchCFace" color="paper" hidden={!on}>
        <Spot radius={0.36} x={-0.36} y={5.02} z={FACE_Z} />
        <Spot radius={0.36} x={0.44} y={5.02} z={FACE_Z} />
        <ToothRow from={-0.46} to={0.54} count={4} y={4.48} length={0.4} width={0.36} way={-1} z={FACE_Z} />
      </ModelPart>
    </>
  );
}

function Pieces({ sketch, words }: { sketch: PosterSketch; words: boolean }) {
  return (
    <>
      <ModelPart name="Pivot" color="ironDark" hidden>
        <Block size={[0.2, 0.2, 0.2]} at={[0, 0.1, 0]} bevel={0} />
      </ModelPart>

      <ModelPart name="Paper" color="paper">
        <Corners points={SHEET} bevel={0} />
      </ModelPart>
      <ModelPart name="Fold" color={[206, 188, 150]}>
        {/* A corner that has curled over. */}
        <Corners
          bevel={0}
          points={[
            [1.62, 0.05, 0.08], [2.7, 0.06, 0.08], [2.7, 1.04, 0.08], [2.7, 1.05, 0.08],
            [1.62, 0.05, 0.12], [2.7, 0.06, 0.12], [2.7, 1.04, 0.12], [2.7, 1.05, 0.12],
          ]}
        />
      </ModelPart>
      <ModelPart name="Border" color="ink">
        <Block size={[5, 0.07, 0.04]} at={[0, 7.05, 0.1]} bevel={0} />
        <Block size={[5, 0.07, 0.04]} at={[0, 0.34, 0.1]} bevel={0} />
        <Block size={[0.07, 6.78, 0.04]} at={[-2.48, 3.7, 0.1]} bevel={0} />
        <Block size={[0.07, 6.78, 0.04]} at={[2.48, 3.7, 0.1]} bevel={0} />
      </ModelPart>
      <ModelPart name="Nail" color="ironDark">
        {[[-2.3, 7.1], [2.32, 7.14]].map(([x, y]) => (
          <Fragment key={x}>
            <Prism sides={6} radius={0.17} height={0.14} at={[x, y, 0.14]} turn={[90, 0, 0]} bevel={0.03} />
          </Fragment>
        ))}
      </ModelPart>
      <ModelPart name="Seal" color="berry">
        <Prism sides={9} radius={0.42} height={0.08} at={[1.82, 0.92, 0.13]} turn={[90, 0, 0]} bevel={0.03} />
      </ModelPart>

      <SketchA on={sketch === "A"} />
      <SketchB on={sketch === "B"} />
      <SketchC on={sketch === "C"} />

      {words && (
        <ModelPart name="ShownWords" color="ink" stage>
          <Block size={[4.1, 0.72, 0.03]} at={[0, 6.54, 0.1]} bevel={0} />
          <Block size={[3.9, 0.24, 0.03]} at={[0, 1.84, 0.1]} bevel={0} />
          <Block size={[3.1, 0.24, 0.03]} at={[0, 1.44, 0.1]} bevel={0} />
          <Block size={[2.7, 0.3, 0.03]} at={[-0.5, 0.86, 0.1]} bevel={0} />
        </ModelPart>
      )}
    </>
  );
}

/**
 * A wanted poster of a mimic, nailed to a wall. It holds three drawings; the game keeps one and
 * writes the words on the paper.
 *
 * @category Models
 */
export function WantedPoster(props: WantedPosterProps): JSX.Element {
  const { sketch = "A", words = true, ...stage } = props;
  return (
    <ModelStage name="WantedPoster" label="A parchment wanted poster with a drawing of a tree with teeth" ground={false} {...stage}>
      <Pieces sketch={sketch} words={words} />
    </ModelStage>
  );
}
