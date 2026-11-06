import { createElement } from "react";
import { markPiece } from "../core/collect";
import { frame } from "../core/math";
import type { Vec3 } from "../core/math";
import type { Color } from "../core/palette";
import { skin, transformed } from "../core/shapes";
import type { SkinRing } from "../core/shapes";
import { ModelStage } from "../stage/ModelStage";

export interface SkinProps {
  /** The rings it goes through, from one end to the other. Each has y and width, and can have depth, x, z and wave. */
  rings: SkinRing[];
  /** How many corners each ring has. 16 by default. */
  sides?: number;
  /** How square the rings are: 2 is an oval, and higher gets closer to a box. 3 by default. */
  squareness?: number;
  /** How many waves a ring with `wave` has. 4 by default. */
  waves?: number;
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
 * One closed skin stretched through rings, for soft bodies like a ghost's sheet. It has no faces
 * hidden inside it, so it stays clean when it's see-through.
 *
 * @category Shapes
 */
export function Skin(props: SkinProps): JSX.Element {
  return <ModelStage>{createElement(Skin, props)}</ModelStage>;
}

markPiece(Skin, {
  kind: "shape",
  polygons: (p: SkinProps) => transformed(skin(p.rings, p.sides ?? 16, p.squareness ?? 3, p.waves ?? 4), frame(p.at, p.turn)),
});
