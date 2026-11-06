import { createElement } from "react";
import type { ReactNode } from "react";
import { markPiece } from "../core/collect";
import type { Vec3 } from "../core/math";
import { ModelStage } from "../stage/ModelStage";

export interface MovingGroupProps {
  /** The group's name. The game finds its parts through their own names. */
  name: string;
  /** The point it turns around: [x, y, z] in studs. */
  hinge?: Vec3;
  /** The line it turns around: "x", "y", "z" or a direction. "x" by default. */
  axis?: "x" | "y" | "z" | Vec3;
  /** How far it is turned, in degrees. With a hinge at the back, a negative angle lifts the front. */
  angle?: number;
  /** How far it swings to each side of `angle`, in degrees. Needs `speed`. */
  swing?: number;
  /** How many swings or sways it makes per second. */
  speed?: number;
  /** How far it is moved, in studs. */
  slide?: Vec3;
  /** How far it sways to each side of `slide`, in studs. Needs `speed`. */
  sway?: Vec3;
  /** The parts that move: ModelPart, Place or another MovingGroup, which then moves with this one. */
  children?: ReactNode;
}

/**
 * Parts that move together around a hinge, like a jaw or a lid. The movement only shows on the
 * stage: models always go to Roblox at rest (with no angle), and the game moves the parts itself.
 *
 * @category Structure
 */
export function MovingGroup(props: MovingGroupProps): JSX.Element {
  return <ModelStage>{createElement(MovingGroup, props)}</ModelStage>;
}

markPiece(MovingGroup, { kind: "group" });
