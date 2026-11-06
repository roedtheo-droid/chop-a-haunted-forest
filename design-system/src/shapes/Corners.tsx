import { createElement } from "react";
import { markPiece } from "../core/collect";
import { frame } from "../core/math";
import type { Vec3 } from "../core/math";
import type { Color } from "../core/palette";
import { corners, transformed } from "../core/shapes";
import { ModelStage } from "../stage/ModelStage";

export interface CornersProps {
  /**
   * Exactly 8 points, [x, y, z] in studs, in this order: left-bottom-back, right-bottom-back,
   * left-top-back, right-top-back, then the same four at the front. The shape must stay convex.
   */
  points: Vec3[];
  /** How much every edge is cut at an angle, in studs. 0.12 by default. */
  bevel?: number;
  /** Moves it: [x, y, z] in studs. */
  at?: Vec3;
  /** Turns it, in degrees around X, Y and Z. */
  turn?: Vec3;
  /** Its colour, when it isn't inside a ModelPart. */
  color?: Color;
  /** Its part's name, when it isn't inside a ModelPart. */
  name?: string;
}

/**
 * A block with its 8 corners placed by hand, for shapes a Block can't make: a root that hugs the
 * ground, or a stump cut at a slant.
 *
 * @category Shapes
 */
export function Corners(props: CornersProps): JSX.Element {
  return <ModelStage>{createElement(Corners, props)}</ModelStage>;
}

markPiece(Corners, {
  kind: "shape",
  polygons: (p: CornersProps) => transformed(corners(p.points, p.bevel ?? 0.12), frame(p.at, p.turn)),
});
