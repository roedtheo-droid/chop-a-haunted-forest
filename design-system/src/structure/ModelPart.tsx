import { createElement } from "react";
import type { ReactNode } from "react";
import { markPiece } from "../core/collect";
import type { Color } from "../core/palette";
import { ModelStage } from "../stage/ModelStage";

export interface ModelPartProps {
  /**
   * The part's name. The game finds parts by name to paint and move them, so use a clear one like
   * "Trunk" or "Teeth". Two parts with the same name become one.
   */
  name: string;
  /** Its colour: a palette name like "bark", "#rrggbb" or [r, g, b]. */
  color?: Color;
  /** See-through amount on the board: 1 is solid. */
  alpha?: number;
  /** Lights itself up on the board, for things that are Neon in the game. Try 0.6. */
  glow?: number;
  /** Goes to Roblox but isn't drawn, like the tiny Pivot box that marks a model's origin. */
  hidden?: boolean;
  /** Only on the board, never exported: props that show the scene around a model. */
  stage?: boolean;
  /** The shapes that make up this part. */
  children?: ReactNode;
}

/**
 * One part of a model: one colour, and one MeshPart in Roblox Studio. Put shapes like Block inside
 * it. Everything inside takes the part's colour.
 *
 * @category Structure
 */
export function ModelPart(props: ModelPartProps): JSX.Element {
  return <ModelStage>{createElement(ModelPart, props)}</ModelStage>;
}

markPiece(ModelPart, { kind: "part" });
