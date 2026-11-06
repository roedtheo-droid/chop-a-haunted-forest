import { createElement } from "react";
import { markPiece } from "../core/collect";
import { length as lengthOf, sub } from "../core/math";
import type { Vec3 } from "../core/math";
import type { Color } from "../core/palette";
import { chain } from "../core/shapes";
import { ModelStage } from "../stage/ModelStage";

export interface ChainProps {
  /** Where it starts: [x, y, z] in studs. */
  from: Vec3;
  /** Where it ends: [x, y, z] in studs. */
  to: Vec3;
  /** How many links it has. Worked out from its length if left out. */
  links?: number;
  /** How far its middle hangs below a straight line, in studs. */
  sag?: number;
  /** How wide a link is, in studs. 0.6 by default. */
  width?: number;
  /** How thick a link's bar is, in studs. 0.17 by default. */
  thickness?: number;
  /** Its colour, when it isn't inside a ModelPart. */
  color?: Color;
  /** Its part's name, when it isn't inside a ModelPart. */
  name?: string;
}

/**
 * A sagging chain of links between two points. Each link is turned against the one before it, like
 * a real chain.
 *
 * @category Shapes
 */
export function Chain(props: ChainProps): JSX.Element {
  return <ModelStage>{createElement(Chain, props)}</ModelStage>;
}

markPiece(Chain, {
  kind: "shape",
  polygons: (p: ChainProps) => {
    const links = p.links ?? Math.max(2, Math.round(lengthOf(sub(p.to, p.from)) / 0.8));
    return chain(p.from, p.to, links, p.sag ?? 0, p.width ?? 0.6, p.thickness ?? 0.17);
  },
});
