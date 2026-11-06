// Helpers for polygons (lists of points), shared by the shapes and the model.

import { add, scale } from "./math";
import type { Vec3 } from "./math";

export type Polygon = Vec3[];

export function centroidOf(points: Vec3[]): Vec3 {
  let c: Vec3 = [0, 0, 0];
  for (const p of points) c = add(c, p);
  return scale(c, 1 / points.length);
}

/** Newell's method: works for any flat polygon, and its length is twice the area. */
export function polygonNormal(p: Polygon): Vec3 {
  const n: Vec3 = [0, 0, 0];
  for (let i = 0; i < p.length; i++) {
    const a = p[i], b = p[(i + 1) % p.length];
    n[0] += (a[1] - b[1]) * (a[2] + b[2]);
    n[1] += (a[2] - b[2]) * (a[0] + b[0]);
    n[2] += (a[0] - b[0]) * (a[1] + b[1]);
  }
  return n;
}
