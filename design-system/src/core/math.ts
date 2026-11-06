// Small vector and matrix helpers. Axes are Roblox's: +Y up, +Z the model's front.

export type Vec3 = [number, number, number];
/** A 4x4 matrix, column by column. */
export type Mat4 = number[];

export const add = (a: Vec3, b: Vec3): Vec3 => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
export const sub = (a: Vec3, b: Vec3): Vec3 => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
export const scale = (a: Vec3, s: number): Vec3 => [a[0] * s, a[1] * s, a[2] * s];
export const dot = (a: Vec3, b: Vec3): number => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
export const cross = (a: Vec3, b: Vec3): Vec3 => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
export const length = (a: Vec3): number => Math.sqrt(dot(a, a));
export const unit = (a: Vec3): Vec3 => {
  const l = length(a);
  return l > 1e-9 ? [a[0] / l, a[1] / l, a[2] / l] : [0, 0, 0];
};
export const lerp = (a: number, b: number, t: number): number => a + (b - a) * t;
export const clamp = (x: number, low: number, high: number): number => Math.min(high, Math.max(low, x));
export const rad = (degrees: number): number => (degrees * Math.PI) / 180;

export const Mat = {
  identity: (): Mat4 => [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
  mul(a: Mat4, b: Mat4): Mat4 {
    const o = new Array<number>(16);
    for (let c = 0; c < 4; c++) {
      for (let r = 0; r < 4; r++) {
        o[c * 4 + r] = a[r] * b[c * 4] + a[4 + r] * b[c * 4 + 1] + a[8 + r] * b[c * 4 + 2] + a[12 + r] * b[c * 4 + 3];
      }
    }
    return o;
  },
  translate: (x: number, y: number, z: number): Mat4 => [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1],
  scale: (x: number, y: number, z: number): Mat4 => [x, 0, 0, 0, 0, y, 0, 0, 0, 0, z, 0, 0, 0, 0, 1],
  rotX(a: number): Mat4 {
    const c = Math.cos(a), s = Math.sin(a);
    return [1, 0, 0, 0, 0, c, s, 0, 0, -s, c, 0, 0, 0, 0, 1];
  },
  rotY(a: number): Mat4 {
    const c = Math.cos(a), s = Math.sin(a);
    return [c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, 0, 0, 0, 1];
  },
  rotZ(a: number): Mat4 {
    const c = Math.cos(a), s = Math.sin(a);
    return [c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
  },
  point(m: Mat4, p: Vec3): Vec3 {
    return [
      m[0] * p[0] + m[4] * p[1] + m[8] * p[2] + m[12],
      m[1] * p[0] + m[5] * p[1] + m[9] * p[2] + m[13],
      m[2] * p[0] + m[6] * p[1] + m[10] * p[2] + m[14],
    ];
  },
  /** The sign tells whether a matrix mirrors things, which turns polygons inside out. */
  determinant3(m: Mat4): number {
    return (
      m[0] * (m[5] * m[10] - m[9] * m[6]) -
      m[4] * (m[1] * m[10] - m[9] * m[2]) +
      m[8] * (m[1] * m[6] - m[5] * m[2])
    );
  },
  perspective(fovy: number, aspect: number, near: number, far: number): Mat4 {
    const f = 1 / Math.tan(fovy / 2), nf = 1 / (near - far);
    return [f / aspect, 0, 0, 0, 0, f, 0, 0, 0, 0, (far + near) * nf, -1, 0, 0, 2 * far * near * nf, 0];
  },
  ortho(l: number, r: number, b: number, t: number, n: number, f: number): Mat4 {
    return [2 / (r - l), 0, 0, 0, 0, 2 / (t - b), 0, 0, 0, 0, -2 / (f - n), 0, -(r + l) / (r - l), -(t + b) / (t - b), -(f + n) / (f - n), 1];
  },
  lookAt(eye: Vec3, target: Vec3, up: Vec3): Mat4 {
    const z = unit(sub(eye, target)), x = unit(cross(up, z)), y = cross(z, x);
    return [x[0], y[0], z[0], 0, x[1], y[1], z[1], 0, x[2], y[2], z[2], 0, -dot(x, eye), -dot(y, eye), -dot(z, eye), 1];
  },
};

/** Like Roblox's CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz), with the angles in degrees. */
export function frame(at?: Vec3, turn?: Vec3): Mat4 {
  let m = at ? Mat.translate(at[0], at[1], at[2]) : Mat.identity();
  if (turn) {
    if (turn[0]) m = Mat.mul(m, Mat.rotX(rad(turn[0])));
    if (turn[1]) m = Mat.mul(m, Mat.rotY(rad(turn[1])));
    if (turn[2]) m = Mat.mul(m, Mat.rotZ(rad(turn[2])));
  }
  return m;
}

/** A frame whose local +X runs along `xAxis`, rolled around it (for chain links). */
export function along(origin: Vec3, xAxis: Vec3, roll: number): Mat4 {
  const x = unit(xAxis);
  const helper: Vec3 = Math.abs(x[1]) > 0.9 ? [1, 0, 0] : [0, 1, 0];
  const z = unit(cross(x, helper));
  const y = cross(z, x);
  const c = Math.cos(roll), s = Math.sin(roll);
  const y2 = add(scale(y, c), scale(z, s));
  const z2 = add(scale(y, -s), scale(z, c));
  return [x[0], x[1], x[2], 0, y2[0], y2[1], y2[2], 0, z2[0], z2[1], z2[2], 0, origin[0], origin[1], origin[2], 1];
}
