import { createElement } from "react";
import { markPiece } from "../core/collect";
import { frame } from "../core/math";
import type { Vec3 } from "../core/math";
import type { Color } from "../core/palette";
import { block, transformed } from "../core/shapes";
import { ModelStage } from "../stage/ModelStage";

export interface BlockProps {
  /** Width (X), height (Y) and depth (Z) in studs. */
  size: Vec3;
  /** Where its middle is: [x, y, z] in studs. With `standing`, where its bottom middle is. */
  at?: Vec3;
  /** Turns it, in degrees around X, Y and Z (like Roblox's CFrame.Angles). */
  turn?: Vec3;
  /** How much every edge is cut at an angle, in studs. 0.12 by default, 0 for sharp edges. */
  bevel?: number;
  /** How big its top is compared with its bottom: a number, or [x, z]. 0.1 makes a point. */
  top?: number | [number, number];
  /** Moves its top sideways, in studs: [x, z]. Makes it lean. */
  shift?: [number, number];
  /** Puts `at` at its bottom middle instead of its middle, so it stands on that spot. */
  standing?: boolean;
  /** Its colour, when it isn't inside a ModelPart. */
  color?: Color;
  /** Its part's name, when it isn't inside a ModelPart. */
  name?: string;
}

/**
 * A chunky block with cut edges, the main building piece. It can taper and lean, which makes
 * tree trunks, teeth, roots and roofs.
 *
 * @category Shapes
 */
export function Block(props: BlockProps): JSX.Element {
  return <ModelStage>{createElement(Block, props)}</ModelStage>;
}

markPiece(Block, {
  kind: "shape",
  polygons: (p: BlockProps) => transformed(block(p), frame(p.at, p.turn)),
});
