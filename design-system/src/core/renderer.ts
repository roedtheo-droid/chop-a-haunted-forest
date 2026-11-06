// Draws a model. All the stages on a page share one WebGL context, because browsers only allow a few
// and a page of component cards can hold many stages. Each stage copies the picture onto its own
// canvas, so a picture stays visible even if the browser takes the context away. Where WebGL isn't
// available at all, a simple painter draws the same model with plain canvas polygons.

import { Mat, add, dot, scale, sub, unit } from "./math";
import type { Mat4, Vec3 } from "./math";
import type { ModelData, PartData } from "./model";
import type { Rgb } from "./palette";

export interface Camera {
  /** Radians around the model: 0 looks at its front (+Z). */
  yaw: number;
  /** Radians above the horizon. */
  pitch: number;
  distance: number;
  target: Vec3;
}

export interface Scene {
  background: Rgb;
  fogNear: number;
  fogFar: number;
  shadowRadius: number;
}

export const FIELD_OF_VIEW = 0.62;
const SUN = unit([-0.5, 0.72, 0.62]);
const SUN_COLOR: Vec3 = [1.3, 1.17, 0.98];
const SKY: Vec3 = [0.5, 0.56, 0.62];
const BOUNCE: Vec3 = [0.3, 0.28, 0.24];
const SHADOW_SIZE = 2048;

const SHADOW_VS = `
attribute vec3 aPos;
uniform mat4 uLight, uModel;
void main(){ gl_Position = uLight * uModel * vec4(aPos, 1.0); }`;
const SHADOW_FS = `
precision highp float;
void main(){
  vec4 enc = fract(vec4(1.0, 255.0, 65025.0, 16581375.0) * gl_FragCoord.z);
  enc -= enc.yzww * vec4(1.0 / 255.0, 1.0 / 255.0, 1.0 / 255.0, 0.0);
  gl_FragColor = enc;
}`;
const MAIN_VS = `
attribute vec3 aPos;
attribute vec3 aNor;
uniform mat4 uViewProj, uModel, uLight;
varying vec3 vN, vW;
varying vec4 vS;
void main(){
  vec4 w = uModel * vec4(aPos, 1.0);
  vW = w.xyz;
  vN = (uModel * vec4(aNor, 0.0)).xyz;
  vS = uLight * w;
  gl_Position = uViewProj * w;
}`;
const MAIN_FS = `
precision highp float;
uniform vec3 uColor, uSun, uCam, uFog, uSunColor, uSky, uBounce;
uniform float uAlpha, uGlow, uFogNear, uFogFar, uTexel, uHasShadow;
uniform sampler2D uShadow;
varying vec3 vN, vW;
varying vec4 vS;
float unpack(vec4 c){ return dot(c, vec4(1.0, 1.0 / 255.0, 1.0 / 65025.0, 1.0 / 16581375.0)); }
float lit(float slope){
  if (uHasShadow < 0.5) return 1.0;
  vec3 p = vS.xyz / vS.w * 0.5 + 0.5;
  if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0 || p.z > 1.0) return 1.0;
  float sum = 0.0;
  float bias = 0.0012 + 0.0035 * (1.0 - slope);
  for (int x = -1; x <= 1; x++) {
    for (int y = -1; y <= 1; y++) {
      sum += (p.z - bias > unpack(texture2D(uShadow, p.xy + vec2(float(x), float(y)) * uTexel))) ? 0.0 : 1.0;
    }
  }
  return sum / 9.0;
}
void main(){
  vec3 n = normalize(vN);
  vec3 albedo = pow(uColor, vec3(2.2));
  vec3 ambient = mix(uBounce, uSky, n.y * 0.5 + 0.5);
  float nl = max(dot(n, uSun), 0.0);
  vec3 color = albedo * (ambient + uSunColor * nl * lit(nl));
  vec3 v = normalize(uCam - vW);
  color += albedo * pow(1.0 - max(dot(n, v), 0.0), 3.0) * 0.14;
  color += albedo * uGlow;
  float f = smoothstep(uFogNear, uFogFar, length(uCam - vW));
  color = mix(color, pow(uFog, vec3(2.2)), f);
  gl_FragColor = vec4(pow(color, vec3(1.0 / 2.2)), uAlpha);
}`;

const srgb = (c: Rgb): Vec3 => [c[0] / 255, c[1] / 255, c[2] / 255];

function eyeOf(camera: Camera): Vec3 {
  const cp = Math.cos(camera.pitch);
  return add(camera.target, [Math.sin(camera.yaw) * cp * camera.distance, Math.sin(camera.pitch) * camera.distance, Math.cos(camera.yaw) * cp * camera.distance]);
}

function partMatrix(part: PartData, time: number): Mat4 {
  return part.group ? part.group.matrix(time) : Mat.identity();
}

interface Program {
  program: WebGLProgram;
  u: Record<string, WebGLUniformLocation | null>;
}

interface Mesh {
  pos: WebGLBuffer;
  nor: WebGLBuffer;
  count: number;
}

class GlRenderer {
  canvas: HTMLCanvasElement;
  gl: WebGLRenderingContext;
  lost = false;
  private main: Program;
  private depth: Program;
  private meshes = new Map<PartData, Mesh>();
  private shadowTex: WebGLTexture;
  private shadowFb: WebGLFramebuffer;
  private hasShadow: boolean;

  constructor() {
    this.canvas = document.createElement("canvas");
    this.canvas.width = this.canvas.height = 16;
    const gl = this.canvas.getContext("webgl", { antialias: true, alpha: false });
    if (!gl) throw new Error("WebGL is not available");
    this.gl = gl;
    this.canvas.addEventListener("webglcontextlost", (e) => {
      e.preventDefault();
      this.lost = true;
    });
    this.main = this.compile(MAIN_VS, MAIN_FS);
    this.depth = this.compile(SHADOW_VS, SHADOW_FS);
    this.shadowTex = gl.createTexture() as WebGLTexture;
    gl.bindTexture(gl.TEXTURE_2D, this.shadowTex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, SHADOW_SIZE, SHADOW_SIZE, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    this.shadowFb = gl.createFramebuffer() as WebGLFramebuffer;
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.shadowFb);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.shadowTex, 0);
    const rb = gl.createRenderbuffer();
    gl.bindRenderbuffer(gl.RENDERBUFFER, rb);
    gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT16, SHADOW_SIZE, SHADOW_SIZE);
    gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, rb);
    this.hasShadow = gl.checkFramebufferStatus(gl.FRAMEBUFFER) === gl.FRAMEBUFFER_COMPLETE;
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  }

  private compile(vs: string, fs: string): Program {
    const gl = this.gl;
    const shader = (type: number, src: string) => {
      const s = gl.createShader(type) as WebGLShader;
      gl.shaderSource(s, src);
      gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s) ?? "shader failed");
      return s;
    };
    const program = gl.createProgram() as WebGLProgram;
    gl.attachShader(program, shader(gl.VERTEX_SHADER, vs));
    gl.attachShader(program, shader(gl.FRAGMENT_SHADER, fs));
    gl.bindAttribLocation(program, 0, "aPos");
    gl.bindAttribLocation(program, 1, "aNor");
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program) ?? "link failed");
    const u: Record<string, WebGLUniformLocation | null> = {};
    const count = gl.getProgramParameter(program, gl.ACTIVE_UNIFORMS);
    for (let i = 0; i < count; i++) {
      const name = (gl.getActiveUniform(program, i) as WebGLActiveInfo).name;
      u[name] = gl.getUniformLocation(program, name);
    }
    return { program, u };
  }

  private meshFor(part: PartData): Mesh {
    let mesh = this.meshes.get(part);
    if (!mesh) {
      const gl = this.gl;
      const pos = gl.createBuffer() as WebGLBuffer;
      gl.bindBuffer(gl.ARRAY_BUFFER, pos);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(part.positions), gl.STATIC_DRAW);
      const nor = gl.createBuffer() as WebGLBuffer;
      gl.bindBuffer(gl.ARRAY_BUFFER, nor);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(part.normals), gl.STATIC_DRAW);
      mesh = { pos, nor, count: part.positions.length / 3 };
      this.meshes.set(part, mesh);
    }
    return mesh;
  }

  /** Frees a model's memory on the graphics card once no stage shows it. */
  release(model: ModelData): void {
    for (const part of model.parts) {
      const mesh = this.meshes.get(part);
      if (mesh) {
        this.gl.deleteBuffer(mesh.pos);
        this.gl.deleteBuffer(mesh.nor);
        this.meshes.delete(part);
      }
    }
  }

  private bind(mesh: Mesh, withNormals: boolean): void {
    const gl = this.gl;
    gl.bindBuffer(gl.ARRAY_BUFFER, mesh.pos);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 0, 0);
    if (withNormals) {
      gl.bindBuffer(gl.ARRAY_BUFFER, mesh.nor);
      gl.enableVertexAttribArray(1);
      gl.vertexAttribPointer(1, 3, gl.FLOAT, false, 0, 0);
    } else {
      gl.disableVertexAttribArray(1);
    }
  }

  draw(model: ModelData, camera: Camera, scene: Scene, time: number, target: CanvasRenderingContext2D, width: number, height: number): void {
    const gl = this.gl;
    if (this.canvas.width < width || this.canvas.height < height) {
      this.canvas.width = Math.max(this.canvas.width, width);
      this.canvas.height = Math.max(this.canvas.height, height);
    }
    const list = model.parts
      .filter((p) => p.triangles > 0 && !p.hidden)
      .map((part) => ({ part, matrix: partMatrix(part, time), mesh: this.meshFor(part) }));

    const r = scene.shadowRadius;
    const lightEye = add(camera.target, scale(SUN, r * 2));
    const light = Mat.mul(Mat.ortho(-r, r, -r, r, 0.5, r * 4), Mat.lookAt(lightEye, camera.target, [0, 1, 0]));

    gl.enable(gl.DEPTH_TEST);
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.BACK);
    gl.disable(gl.BLEND);
    if (this.hasShadow) {
      gl.bindFramebuffer(gl.FRAMEBUFFER, this.shadowFb);
      gl.viewport(0, 0, SHADOW_SIZE, SHADOW_SIZE);
      gl.clearColor(1, 1, 1, 1);
      gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
      gl.useProgram(this.depth.program);
      gl.uniformMatrix4fv(this.depth.u.uLight, false, light);
      for (const item of list) {
        if (item.part.alpha < 0.5) continue;
        this.bind(item.mesh, false);
        gl.uniformMatrix4fv(this.depth.u.uModel, false, item.matrix);
        gl.drawArrays(gl.TRIANGLES, 0, item.mesh.count);
      }
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    }

    const fog = srgb(scene.background);
    gl.viewport(0, 0, width, height);
    gl.enable(gl.SCISSOR_TEST);
    gl.scissor(0, 0, width, height);
    gl.clearColor(fog[0], fog[1], fog[2], 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.disable(gl.SCISSOR_TEST);
    const eye = eyeOf(camera);
    const viewProj = Mat.mul(Mat.perspective(FIELD_OF_VIEW, width / height, 0.5, 2000), Mat.lookAt(eye, camera.target, [0, 1, 0]));

    const m = this.main;
    gl.useProgram(m.program);
    gl.uniformMatrix4fv(m.u.uViewProj, false, viewProj);
    gl.uniformMatrix4fv(m.u.uLight, false, light);
    gl.uniform3fv(m.u.uSun, SUN);
    gl.uniform3fv(m.u.uCam, eye);
    gl.uniform3fv(m.u.uFog, fog);
    gl.uniform3fv(m.u.uSunColor, SUN_COLOR);
    gl.uniform3fv(m.u.uSky, SKY);
    gl.uniform3fv(m.u.uBounce, BOUNCE);
    gl.uniform1f(m.u.uFogNear, scene.fogNear);
    gl.uniform1f(m.u.uFogFar, scene.fogFar);
    gl.uniform1f(m.u.uTexel, 1 / SHADOW_SIZE);
    gl.uniform1f(m.u.uHasShadow, this.hasShadow ? 1 : 0);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.shadowTex);
    gl.uniform1i(m.u.uShadow, 0);

    const pass = (items: typeof list) => {
      for (const item of items) {
        this.bind(item.mesh, true);
        gl.uniformMatrix4fv(m.u.uModel, false, item.matrix);
        gl.uniform3fv(m.u.uColor, srgb(item.part.color));
        gl.uniform1f(m.u.uAlpha, item.part.alpha);
        gl.uniform1f(m.u.uGlow, item.part.glow);
        gl.drawArrays(gl.TRIANGLES, 0, item.mesh.count);
      }
    };
    pass(list.filter((i) => i.part.alpha >= 1));
    const clear = list.filter((i) => i.part.alpha < 1);
    if (clear.length) {
      gl.enable(gl.BLEND);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      pass(clear);
      gl.disable(gl.BLEND);
    }
    target.drawImage(this.canvas, 0, this.canvas.height - height, width, height, 0, 0, width, height);
  }
}

let shared: GlRenderer | null | undefined;

function renderer(): GlRenderer | null {
  if (shared && shared.lost) shared = null;
  if (shared === undefined) {
    try {
      shared = new GlRenderer();
    } catch {
      shared = null;
    }
  }
  return shared;
}

/** Does this browser draw with WebGL? (Otherwise the plain painter is used.) */
export function usesWebGl(): boolean {
  return renderer() !== null;
}

/** The plain painter: flat polygons, furthest first, with no cast shadows. */
function paint(ctx: CanvasRenderingContext2D, model: ModelData, camera: Camera, scene: Scene, time: number, width: number, height: number): void {
  const eye = eyeOf(camera);
  const view = Mat.lookAt(eye, camera.target, [0, 1, 0]);
  const proj = Mat.perspective(FIELD_OF_VIEW, width / height, 0.5, 2000);
  const viewProj = Mat.mul(proj, view);
  const bg = scene.background;
  ctx.fillStyle = `rgb(${bg[0]},${bg[1]},${bg[2]})`;
  ctx.fillRect(0, 0, width, height);
  const items: { depth: number; points: number[]; fill: string; ground: boolean }[] = [];
  for (const part of model.parts) {
    if (part.hidden || part.triangles === 0) continue;
    const matrix = partMatrix(part, time);
    const albedo: Vec3 = [Math.pow(part.color[0] / 255, 2.2), Math.pow(part.color[1] / 255, 2.2), Math.pow(part.color[2] / 255, 2.2)];
    const ground = part.name === "Ground";
    for (let i = 0; i < part.positions.length; i += 9) {
      const a = Mat.point(matrix, [part.positions[i], part.positions[i + 1], part.positions[i + 2]]);
      const b = Mat.point(matrix, [part.positions[i + 3], part.positions[i + 4], part.positions[i + 5]]);
      const c = Mat.point(matrix, [part.positions[i + 6], part.positions[i + 7], part.positions[i + 8]]);
      const local: Vec3 = [part.normals[i], part.normals[i + 1], part.normals[i + 2]];
      const n = unit(sub(Mat.point(matrix, local), Mat.point(matrix, [0, 0, 0])));
      const middle: Vec3 = [(a[0] + b[0] + c[0]) / 3, (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3];
      if (dot(n, sub(eye, middle)) <= 0) continue;
      const points: number[] = [];
      let behind = false;
      for (const p of [a, b, c]) {
        const x = viewProj[0] * p[0] + viewProj[4] * p[1] + viewProj[8] * p[2] + viewProj[12];
        const y = viewProj[1] * p[0] + viewProj[5] * p[1] + viewProj[9] * p[2] + viewProj[13];
        const w = viewProj[3] * p[0] + viewProj[7] * p[1] + viewProj[11] * p[2] + viewProj[15];
        if (w <= 0.1) {
          behind = true;
          break;
        }
        points.push(((x / w) * 0.5 + 0.5) * width, (0.5 - (y / w) * 0.5) * height);
      }
      if (behind) continue;
      const nl = Math.max(dot(n, SUN), 0);
      const up = n[1] * 0.5 + 0.5;
      const light = [0, 1, 2].map((k) => BOUNCE[k] + (SKY[k] - BOUNCE[k]) * up + SUN_COLOR[k] * nl);
      const color = [0, 1, 2].map((k) => Math.round(Math.pow(Math.min(albedo[k] * (light[k] + part.glow), 1), 1 / 2.2) * 255));
      items.push({ depth: dot(sub(middle, eye), sub(middle, eye)), points, fill: `rgba(${color[0]},${color[1]},${color[2]},${part.alpha})`, ground });
    }
  }
  items.sort((p, q) => (p.ground === q.ground ? q.depth - p.depth : p.ground ? -1 : 1));
  ctx.lineWidth = 0.7;
  for (const item of items) {
    const [x0, y0, x1, y1, x2, y2] = item.points;
    ctx.beginPath();
    ctx.moveTo(x0, y0);
    ctx.lineTo(x1, y1);
    ctx.lineTo(x2, y2);
    ctx.closePath();
    ctx.fillStyle = item.fill;
    ctx.strokeStyle = item.fill;
    ctx.fill();
    ctx.stroke();
  }
}

/** Draw `model` onto a stage's own 2D canvas. */
export function drawModel(ctx: CanvasRenderingContext2D, model: ModelData, camera: Camera, scene: Scene, time: number, width: number, height: number): void {
  const gl = renderer();
  if (gl) {
    try {
      gl.draw(model, camera, scene, time, ctx, width, height);
      return;
    } catch {
      shared = null;
    }
  }
  paint(ctx, model, camera, scene, time, width, height);
}

export function releaseModel(model: ModelData): void {
  if (shared) shared.release(model);
}
