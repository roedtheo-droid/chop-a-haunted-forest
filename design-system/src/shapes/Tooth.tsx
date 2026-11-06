import { createElement } from "react";
import { markPiece } from "../core/collect";
import { Mat, frame } from "../core/math";
import type { Vec3 } from "../core/math";
import type { Color } from "../core/palette";
import { block, transformed } from "../core/shapes";
import { ModelStage } from "../stage/ModelStage";

export interface ToothProps {
  /** Width at its root, in studs. */
  width: number;
  /** Length from root to tip, in studs. */
  length: number;
  /** Depth at its root, in studs. Same as `width` if left out. */
  depth?: number;
  /** Where its root is: [x, y, z] in studs. */
  at?: Vec3;
  /** Turns it, in degrees around X, Y and Z. */
  turn?: Vec3;
  /** Points it down instead of up, for the top row of a mouth. */
  down?: boolean;
  /** How big its tip is compared with its root. 0.16 by default. */
  tip?: number;
  /** Its colour, when it isn't inside a ModelPart. */
  color?: Color;
  /** Its part's name, when it isn't inside a ModelPart. */
  name?: string;
}

/**
 * A chunky tooth that tapers to a blunt tip. Teeth are the game's signature, so make them big and
 * uneven. Works for fangs, claws, thorns and spikes too.
 *
 * @category Shapes
 */
export function Tooth(props: ToothProps): JSX.Element {
  return <ModelStage>{createElement(Tooth, props)}</ModelStage>;
}

markPiece(Tooth, {
  kind: "shape",
  polygons: (p: ToothProps) => {
    const shape = block({
      size: [p.width, p.length, p.depth ?? p.width],
      standing: true,
      top: p.tip ?? 0.16,
      bevel: Math.min(0.08, p.width * 0.08),
    });
    const flip = p.down ? Mat.rotX(Math.PI) : Mat.identity();
    return transformed(shape, Mat.mul(frame(p.at, p.turn), flip));
  },
});
