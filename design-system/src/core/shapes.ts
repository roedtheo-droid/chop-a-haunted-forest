// The shapes, as lists of polygons. Everything is chunky with cut edges, because the game's style
// guide wants no spheres and no smooth round things: the slanted edges are what catch the light.

import { Mat, add, along, dot, length, lerp, scale, sub } from "./math";
import type { Mat4, Vec3 } from "./math";
import { centroidOf, polygonNormal } from "./polygons";
import type { Polygon } from "./polygons";

function outward(polygons: Polygon[], center: Vec3): Polygon[] {
  const out: Polygon[] = [];
  for (const p of polygons) {
    const n = polygonNormal(p);
    if (length(n) < 1e-7) continue; // a corner squashed to nothing
    out.push(dot(n, sub(centroidOf(p), center)) < 0 ? p.slice().reverse() : p);
  }
  return out;
}

export function transformed(polygons: Polygon[], m: Mat4): Polygon[] {
  return polygons.map((p) => p.map((q) => Mat.point(m, q)));
}

/**
 * Eight corners, numbered by bits: 1 = +X, 2 = +Y, 4 = +Z. `bevel` cuts every edge at an angle.
 * Corners can be anywhere, as long as the shape stays convex.
 */
export function corners(c: Vec3[], bevel: number): Polygon[] {
  const center = centroidOf(c);
  const polygons: Polygon[] = [];
  const faces = (pick: (corner: number, axis: number) => Vec3) => {
    for (let a = 0; a < 3; a++) {
      const p = (a + 1) % 3, r = (a + 2) % 3;
      for (let side = 0; side < 2; side++) {
        const base = side << a;
        polygons.push([base, base | (1 << p), base | (1 << p) | (1 << r), base | (1 << r)].map((i) => pick(i, a)));
      }
    }
  };
  if (!bevel) {
    faces((i) => c[i]);
    return outward(polygons, center);
  }
  const cut = (i: number, a: number): Vec3 => {
    let point = c[i];
    for (let k = 0; k < 3; k++) {
      if (k === a) continue;
      const edge = sub(c[i ^ (1 << k)], c[i]);
      const l = length(edge);
      if (l > 1e-6) point = add(point, scale(edge, Math.min(bevel, l * 0.45) / l));
    }
    return point;
  };
  faces(cut);
  for (let i = 0; i < 8; i++) {
    polygons.push([cut(i, 0), cut(i, 1), cut(i, 2)]);
    for (let a = 0; a < 3; a++) {
      const j = i ^ (1 << a);
      if (j < i) continue;
      const p = (a + 1) % 3, r = (a + 2) % 3;
      polygons.push([cut(i, p), cut(i, r), cut(j, r), cut(j, p)]);
    }
  }
  return outward(polygons, center);
}

export interface BlockShape {
  size: Vec3;
  bevel?: number;
  /** How big the top is compared with the bottom: a number or [x, z]. */
  top?: number | [number, number];
  /** Moves the top sideways: [x, z]. */
  shift?: [number, number];
  /** Stand on y = 0 instead of being centred. */
  standing?: boolean;
}

export function block(o: BlockShape): Polygon[] {
  const [w, h, d] = o.size;
  const top: [number, number] = o.top === undefined ? [1, 1] : typeof o.top === "number" ? [o.top, o.top] : o.top;
  const shift = o.shift ?? [0, 0];
  const y0 = o.standing ? 0 : -h / 2;
  const c: Vec3[] = [];
  for (let i = 0; i < 8; i++) {
    const sx = i & 1 ? 0.5 : -0.5, sz = i & 4 ? 0.5 : -0.5;
    const up = !!(i & 2);
    c.push([sx * w * (up ? top[0] : 1) + (up ? shift[0] : 0), y0 + (up ? h : 0), sz * d * (up ? top[1] : 1) + (up ? shift[1] : 0)]);
  }
  return corners(c, o.bevel ?? 0.12);
}

/** A closed skin through rings of points (all the same count), from one end to the other. */
export function loft(rings: Vec3[][]): Polygon[] {
  const polygons: Polygon[] = [];
  const n = rings[0].length;
  for (let k = 0; k < rings.length - 1; k++) {
    const a = rings[k], b = rings[k + 1];
    const center = centroidOf(a.concat(b));
    for (let i = 0; i < n; i++) {
      const j = (i + 1) % n;
      polygons.push(...outward([[a[i], a[j], b[j], b[i]]], center));
    }
  }
  const all = centroidOf(rings.reduce<Vec3[]>((list, ring) => list.concat(ring), []));
  polygons.push(...outward([rings[0]], all));
  polygons.push(...outward([rings[rings.length - 1]], all));
  return polygons;
}

export interface PrismShape {
  sides?: number;
  radius: number;
  height: number;
  bevel?: number;
  /** How big the top is compared with the bottom. */
  top?: number;
}

/** An n-sided block standing along Y around its middle, with slanted rims. */
export function prism(o: PrismShape): Polygon[] {
  const n = o.sides ?? 8;
  const b = Math.min(o.bevel ?? 0.1, o.radius * 0.4, o.height * 0.4);
  const ring = (radius: number, y: number): Vec3[] => {
    const points: Vec3[] = [];
    for (let i = 0; i < n; i++) {
      const t = ((i + 0.5) / n) * Math.PI * 2;
      points.push([Math.cos(t) * radius, y, Math.sin(t) * radius]);
    }
    return points;
  };
  const rt = o.radius * (o.top ?? 1);
  return loft([ring(o.radius - b, -o.height / 2), ring(o.radius, -o.height / 2 + b), ring(rt, o.height / 2 - b), ring(rt - b, o.height / 2)]);
}

/** One chain link in its local XY plane, long along X. */
export function chainLink(linkLength: number, width: number, bar: number): Polygon[] {
  const polygons: Polygon[] = [];
  for (const y of [-width / 2, width / 2]) {
    polygons.push(...transformed(block({ size: [linkLength + bar, bar, bar], bevel: 0 }), Mat.translate(0, y, 0)));
  }
  for (const x of [-linkLength / 2, linkLength / 2]) {
    polygons.push(...transformed(block({ size: [bar, width, bar], bevel: 0 }), Mat.translate(x, 0, 0)));
  }
  return polygons;
}

/** A sagging chain of links between two points. */
export function chain(from: Vec3, to: Vec3, links: number, sag: number, width: number, bar: number): Polygon[] {
  const polygons: Polygon[] = [];
  const at = (t: number): Vec3 => {
    const p: Vec3 = [lerp(from[0], to[0], t), lerp(from[1], to[1], t), lerp(from[2], to[2], t)];
    p[1] -= 4 * sag * t * (1 - t);
    return p;
  };
  for (let i = 0; i < links; i++) {
    const a = at(i / links), b = at((i + 1) / links);
    const middle: Vec3 = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2];
    const dir = sub(b, a);
    polygons.push(...transformed(chainLink(length(dir) * 1.05, width, bar), along(middle, dir, i % 2 ? Math.PI / 2 : 0)));
  }
  return polygons;
}

export interface SkinRing {
  /** Height of this ring. */
  y: number;
  /** Half its width along X. */
  width: number;
  /** Half its depth along Z (same as width if left out). */
  depth?: number;
  /** Moves the ring along X and Z. */
  x?: number;
  z?: number;
  /** Makes the ring wavy: how far its points go up and down. */
  wave?: number;
}

/**
 * A closed skin through rings around Y, with no faces hidden inside it, so it stays clean when it
 * is see-through (a ghost). `squareness` 2 is an oval, higher values get closer to a box.
 */
export function skin(rings: SkinRing[], sides: number, squareness: number, waves: number): Polygon[] {
  const exponent = 2 / Math.max(squareness, 0.5);
  const lofted: Vec3[][] = rings.map((ring) => {
    const points: Vec3[] = [];
    for (let i = 0; i < sides; i++) {
      const t = ((i + 0.5) / sides) * Math.PI * 2;
      const c = Math.cos(t), s = Math.sin(t);
      const px = Math.sign(c) * Math.pow(Math.abs(c), exponent);
      const pz = Math.sign(s) * Math.pow(Math.abs(s), exponent);
      const wave = ring.wave ? Math.cos(t * waves) * ring.wave : 0;
      points.push([(ring.x ?? 0) + px * ring.width, ring.y + wave, (ring.z ?? 0) + pz * (ring.depth ?? ring.width)]);
    }
    return points;
  });
  return loft(lofted);
}
