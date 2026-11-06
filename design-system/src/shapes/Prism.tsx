import { createElement } from "react";
import { markPiece } from "../core/collect";
import { frame } from "../core/math";
import type { Vec3 } from "../core/math";
import type { Color } from "../core/palette";
import { prism, transformed } from "../core/shapes";
import { ModelStage } from "../stage/ModelStage";

export interface PrismProps {
  /** How many sides it has. 8 by default. Keep it low: 6 to 12 fits the chunky look. */
  sides?: number;
  /** How far its corners are from its middle, in studs. */
  radius: number;
  /** Its height, in studs. */
  height: number;
  /** Where its middle is: [x, y, z] in studs. */
  at?: Vec3;
  /** Turns it, in degrees. It stands along Y, so turn [90, 0, 0] makes it face the front. */
  turn?: Vec3;
  /** How much its rims are cut at an angle, in studs. 0.1 by default. */
  bevel?: number;
  /** How big its top is compared with its bottom. */
  top?: number;
  /** Its colour, when it isn't inside a ModelPart. */
  color?: Color;
  /** Its part's name, when it isn't inside a ModelPart. */
  name?: string;
}

/**
 * A block with several sides, for anything roundish in a game that has no spheres: eyes, coins,
 * barrels and knots in the wood.
 *
 * @category Shapes
 */
export function Prism(props: PrismProps): JSX.Element {
  return <ModelStage>{createElement(Prism, props)}</ModelStage>;
}

markPiece(Prism, {
  kind: "shape",
  polygons: (p: PrismProps) => transformed(prism(p), frame(p.at, p.turn)),
});
