import { createElement } from "react";
import type { ReactNode } from "react";
import { markPiece } from "../core/collect";
import type { Vec3 } from "../core/math";
import { ModelStage } from "../stage/ModelStage";

export interface PlaceProps {
  /** Moves everything inside: [x, y, z] in studs. */
  at?: Vec3;
  /** Turns everything inside, in degrees around X, Y and Z (like Roblox's CFrame.Angles). */
  turn?: Vec3;
  /** Makes everything inside bigger or smaller: 1 is the same size. */
  scale?: number;
  /** Flips left and right, so one side of a model can be reused for the other. */
  mirror?: boolean;
  /** The pieces to move. */
  children?: ReactNode;
}

/**
 * Moves, turns, scales or mirrors a group of pieces together. Use it to build a detail once and
 * put it in several places, like a pair of eyes or a ring of roots.
 *
 * @category Structure
 */
export function Place(props: PlaceProps): JSX.Element {
  return <ModelStage>{createElement(Place, props)}</ModelStage>;
}

markPiece(Place, { kind: "place" });
