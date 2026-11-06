// Reads a tree of React pieces (<ModelPart>, <Block>...) into a ModelData. The pieces are never
// rendered into the page: they are read like data, which is why a model component must be a plain
// function with no hooks. A plain function that returns more pieces is simply called.

import { Fragment, isValidElement } from "react";
import type { ReactNode } from "react";
import { Mat, frame } from "./math";
import type { Mat4, Vec3 } from "./math";
import type { Polygon } from "./polygons";
import { GroupData, ModelData, PartData } from "./model";
import type { Color } from "./palette";
import { resolveColor } from "./palette";

export type Mark =
  | { kind: "stage" }
  | { kind: "part" }
  | { kind: "place" }
  | { kind: "group" }
  | { kind: "shape"; polygons: (props: any) => Polygon[] };

/** Attaches what a component is, so the reader can tell the pieces apart. */
export function markPiece<T extends object>(component: T, mark: Mark): T {
  (component as any).__twt = mark;
  return component;
}

interface Walk {
  model: ModelData;
  matrix: Mat4;
  part: PartData | null;
  group: GroupData | null;
}

function partFor(state: Walk, name: string, color: Color | undefined, extra: { alpha?: number; glow?: number; hidden?: boolean }): PartData {
  const rgb = resolveColor(color);
  const same = state.model.parts.find((p) => p.name === name && p.group === state.group);
  if (same) return same;
  const part = new PartData(name, rgb, { group: state.group, ...extra });
  state.model.parts.push(part);
  return part;
}

function walk(node: ReactNode, state: Walk): void {
  if (node === null || node === undefined || typeof node !== "object") return;
  if (Array.isArray(node)) {
    for (const child of node) walk(child, state);
    return;
  }
  if (!isValidElement(node)) return;
  const type = node.type as any;
  const props = node.props as any;
  if (type === Fragment) {
    walk(props.children, state);
    return;
  }
  if (typeof type !== "function") return; // ordinary page elements aren't part of a model
  const mark: Mark | undefined = type.__twt;
  if (!mark) {
    if (type.prototype && type.prototype.isReactComponent) return;
    walk(type(props), state);
    return;
  }
  switch (mark.kind) {
    case "stage":
      walk(props.children, state);
      return;
    case "part":
      walk(props.children, { ...state, part: partFor(state, props.name, props.color, props) });
      return;
    case "place": {
      // A mirror flips across X = 0 of the frame it stands in, so left and right can share pieces.
      const base = props.mirror ? Mat.mul(state.matrix, Mat.scale(-1, 1, 1)) : state.matrix;
      let matrix = Mat.mul(base, frame(props.at as Vec3 | undefined, props.turn as Vec3 | undefined));
      if (props.scale) matrix = Mat.mul(matrix, Mat.scale(props.scale, props.scale, props.scale));
      walk(props.children, { ...state, matrix });
      return;
    }
    case "group": {
      const group = new GroupData();
      group.name = props.name;
      group.parent = state.group;
      group.hinge = Mat.point(state.matrix, props.hinge ?? [0, 0, 0]);
      group.axis = axisVector(props.axis);
      group.angle = props.angle ?? 0;
      group.swing = props.swing ?? 0;
      group.speed = props.speed ?? 0;
      group.slide = props.slide ?? [0, 0, 0];
      group.sway = props.sway ?? [0, 0, 0];
      state.model.groups.push(group);
      walk(props.children, { ...state, group, part: null });
      return;
    }
    case "shape": {
      // A shape outside a <ModelPart> gets a part of its own.
      const part = state.part ?? partFor(state, props.name ?? `Part${state.model.parts.length + 1}`, props.color, {});
      part.add(mark.polygons(props), state.matrix);
      return;
    }
  }
}

function axisVector(axis: "x" | "y" | "z" | Vec3 | undefined): Vec3 {
  if (Array.isArray(axis)) return axis;
  if (axis === "y") return [0, 1, 0];
  if (axis === "z") return [0, 0, 1];
  return [1, 0, 0];
}

/** Turn React pieces into model data, for the live view or for writing a .gltf file. */
export function collectModel(children: ReactNode, name = "Model"): ModelData {
  const model = new ModelData(name);
  walk(children, { model, matrix: Mat.identity(), part: null, group: null });
  return model;
}
