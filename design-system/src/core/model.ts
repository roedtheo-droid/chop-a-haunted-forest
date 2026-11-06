// What a model is once its React pieces have been read: a list of parts, each one colour.

import { Mat, rad, unit } from "./math";
import type { Mat4, Vec3 } from "./math";
import { polygonNormal } from "./polygons";
import type { Polygon } from "./polygons";
import type { Rgb } from "./palette";

/** A hinge or slide that moves some parts. Nested groups move with their parent. */
export class GroupData {
  name = "";
  parent: GroupData | null = null;
  /** The point it turns around, in model space. */
  hinge: Vec3 = [0, 0, 0];
  axis: Vec3 = [1, 0, 0];
  /** How far it is turned now, in degrees (only on the board: exports stay in the rest pose). */
  angle = 0;
  /** How far it swings around `angle`, and how many times a second. */
  swing = 0;
  speed = 0;
  /** How far it slides now, and how far it sways around that. */
  slide: Vec3 = [0, 0, 0];
  sway: Vec3 = [0, 0, 0];

  /** Where this group's parts are at `time` seconds. */
  matrix(time: number): Mat4 {
    const wave = this.speed ? Math.sin(time * this.speed * Math.PI * 2) : 0;
    const degrees = this.angle + this.swing * wave;
    let m = Mat.identity();
    if (degrees) {
      const [x, y, z] = this.hinge;
      const a = unit(this.axis);
      const turn = axisAngle(a, rad(degrees));
      m = Mat.mul(Mat.translate(x, y, z), Mat.mul(turn, Mat.translate(-x, -y, -z)));
    }
    const sx = this.slide[0] + this.sway[0] * wave;
    const sy = this.slide[1] + this.sway[1] * wave;
    const sz = this.slide[2] + this.sway[2] * wave;
    if (sx || sy || sz) m = Mat.mul(Mat.translate(sx, sy, sz), m);
    return this.parent ? Mat.mul(this.parent.matrix(time), m) : m;
  }

  get moves(): boolean {
    return !!this.speed && (!!this.swing || !!this.sway[0] || !!this.sway[1] || !!this.sway[2]);
  }
}

function axisAngle(a: Vec3, angle: number): Mat4 {
  const c = Math.cos(angle), s = Math.sin(angle), t = 1 - c;
  const [x, y, z] = a;
  return [
    t * x * x + c, t * x * y + s * z, t * x * z - s * y, 0,
    t * x * y - s * z, t * y * y + c, t * y * z + s * x, 0,
    t * x * z + s * y, t * y * z - s * x, t * z * z + c, 0,
    0, 0, 0, 1,
  ];
}

export interface PartOptions {
  group?: GroupData | null;
  /** Only on the board, never exported (the ground, a person for scale). */
  stage?: boolean;
  /** Exported but not drawn (the Pivot box). */
  hidden?: boolean;
  alpha?: number;
  glow?: number;
}

/** One part: one colour, and one MeshPart in Studio. */
export class PartData {
  group: GroupData | null;
  stage: boolean;
  hidden: boolean;
  alpha: number;
  glow: number;
  positions: number[] = [];
  normals: number[] = [];

  constructor(public name: string, public color: Rgb, o: PartOptions = {}) {
    this.group = o.group ?? null;
    this.stage = !!o.stage;
    this.hidden = !!o.hidden;
    this.alpha = o.alpha ?? 1;
    this.glow = o.glow ?? 0;
  }

  add(polygons: Polygon[], m?: Mat4): this {
    const flip = m ? Mat.determinant3(m) < 0 : false;
    for (const original of polygons) {
      let p = m ? original.map((q) => Mat.point(m, q)) : original;
      if (flip) p = p.slice().reverse();
      const n = unit(polygonNormal(p));
      for (let i = 1; i < p.length - 1; i++) {
        for (const q of [p[0], p[i], p[i + 1]]) {
          this.positions.push(q[0], q[1], q[2]);
          this.normals.push(n[0], n[1], n[2]);
        }
      }
    }
    return this;
  }

  get triangles(): number {
    return this.positions.length / 9;
  }
}

export class ModelData {
  parts: PartData[] = [];
  groups: GroupData[] = [];

  constructor(public name: string) {}

  /** The parts that go to Roblox. */
  get exported(): PartData[] {
    return this.parts.filter((p) => !p.stage && p.triangles > 0);
  }

  get triangleCount(): number {
    return this.exported.reduce((sum, p) => sum + p.triangles, 0);
  }

  get animated(): boolean {
    return this.groups.some((g) => g.moves);
  }

  /** The box around everything drawn, as it's posed, with moving parts at both ends of their swing. */
  bounds(includeStage: boolean): { min: Vec3; max: Vec3 } {
    const min: Vec3 = [Infinity, Infinity, Infinity], max: Vec3 = [-Infinity, -Infinity, -Infinity];
    for (const part of this.parts) {
      if (part.hidden || (part.stage && !includeStage)) continue;
      const poses: Mat4[] = [];
      if (part.group) {
        // A quarter and three quarters of a swing are its two ends.
        for (let g: GroupData | null = part.group; g; g = g.parent) {
          if (g.moves) {
            poses.push(part.group.matrix(0.25 / g.speed), part.group.matrix(0.75 / g.speed));
          }
        }
        poses.push(part.group.matrix(0));
      }
      for (let i = 0; i < part.positions.length; i += 3) {
        const p: Vec3 = [part.positions[i], part.positions[i + 1], part.positions[i + 2]];
        for (const q of poses.length ? poses.map((m) => Mat.point(m, p)) : [p]) {
          for (let k = 0; k < 3; k++) {
            min[k] = Math.min(min[k], q[k]);
            max[k] = Math.max(max[k], q[k]);
          }
        }
      }
    }
    if (!isFinite(min[0])) return { min: [-1, 0, -1], max: [1, 2, 1] };
    return { min, max };
  }
}
