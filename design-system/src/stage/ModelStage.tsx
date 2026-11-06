import { useEffect, useMemo, useRef } from "react";
import type { CSSProperties, ReactNode } from "react";
import { collectModel } from "../core/collect";
import { markPiece } from "../core/collect";
import { clamp, rad } from "../core/math";
import type { Vec3 } from "../core/math";
import { PartData } from "../core/model";
import type { ModelData } from "../core/model";
import { palette, resolveColor } from "../core/palette";
import type { Color } from "../core/palette";
import { FIELD_OF_VIEW, drawModel, releaseModel } from "../core/renderer";
import type { Camera, Scene } from "../core/renderer";
import { block, prism } from "../core/shapes";
import { frame } from "../core/math";

export interface ModelStageProps {
  /** The model's name. It becomes the file name when the model goes to Roblox Studio. */
  name?: string;
  /** Width in pixels, or any CSS width like "100%". */
  width?: number | string;
  /** Height in pixels, or any CSS height. */
  height?: number | string;
  /** Degrees around the model. 0 looks straight at its front (+Z), 90 at its right side. */
  yaw?: number;
  /** Degrees above the horizon: 0 is level, 90 looks straight down. */
  pitch?: number;
  /** How far away the camera is, in studs. Leave it out and the model is framed for you. */
  distance?: number;
  /** The point the camera looks at, in studs. Leave it out to use the model's middle. */
  target?: Vec3;
  /** Turns the model by itself, in degrees per second, until someone drags it. */
  spin?: number;
  /** Shows the grass under the model. On by default. */
  ground?: boolean;
  /** Stands a 5.5-stud person next to the model, to show its size in the game. */
  person?: boolean;
  /** The colour behind the model: a palette name, "#rrggbb" or [r, g, b]. Misty by default. */
  background?: Color;
  /** Lets people drag to turn the model. On by default. */
  draggable?: boolean;
  /** What the model is, for screen readers. */
  label?: string;
  style?: CSSProperties;
  /** The model: <ModelPart>, <Place>, <MovingGroup> and shapes like <Block>. */
  children?: ReactNode;
}

function addPerson(model: ModelData, x: number, z: number): void {
  const person = new PartData("Person", palette.person, { stage: true });
  const add = (size: Vec3, at: Vec3) => person.add(block({ size, bevel: 0.06 }), frame(at));
  add([1.8, 1.8, 1.8], [x, 4.6, z]);
  add([2, 2, 1], [x, 2.9, z]);
  add([0.9, 2, 1], [x - 1.45, 2.9, z]);
  add([0.9, 2, 1], [x + 1.45, 2.9, z]);
  add([0.95, 1.9, 1], [x - 0.5, 0.95, z]);
  add([0.95, 1.9, 1], [x + 0.5, 0.95, z]);
  model.parts.push(person);
}

function addGround(model: ModelData, radius: number): void {
  const ground = new PartData("Ground", palette.grass, { stage: true });
  ground.add(prism({ sides: 24, radius, height: 0.4, bevel: 0 }), frame([0, -0.21, 0]));
  model.parts.push(ground);
}

interface Built {
  model?: ModelData;
  error?: string;
}

function build(props: ModelStageProps): Built {
  try {
    const model = collectModel(props.children, props.name ?? "Model");
    if (props.person) {
      const { max } = model.bounds(false);
      addPerson(model, Math.max(max[0], 0) + 3.5, Math.max(max[2], 0) * 0.5);
    }
    return { model };
  } catch (error) {
    return { error: error instanceof Error ? error.message : String(error) };
  }
}

/**
 * Shows a 3D model live: drag to turn it. Build the model inside it from ModelPart, Block and the
 * other pieces. The same pieces can be written out as a .gltf file for Roblox Studio.
 *
 * @category Stage
 */
export function ModelStage(props: ModelStageProps): JSX.Element {
  const { width = 480, height = 360, yaw = 28, pitch = 14, spin = 0, ground = true, draggable = true } = props;
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const built = useMemo(() => build(props), [props.children, props.name, props.person]);
  const look = useRef({ yaw: rad(yaw), pitch: rad(pitch), dragged: false, shown: rad(yaw) });
  const draw = useRef<() => void>(() => undefined);

  useEffect(() => {
    look.current.yaw = rad(yaw);
    look.current.pitch = rad(pitch);
    look.current.dragged = false;
    draw.current();
  }, [yaw, pitch]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const model = built.model;
    if (!canvas || !model) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    // This runs again when a prop changes, so take away the ground from the last time first.
    model.parts = model.parts.filter((p) => p.name !== "Ground");
    const { min, max } = model.bounds(!!props.person);
    const middle: Vec3 = [(min[0] + max[0]) / 2, (min[1] + max[1]) / 2, (min[2] + max[2]) / 2];
    const half = Math.max(0.5, Math.hypot(max[0] - min[0], max[1] - min[1], max[2] - min[2]) / 2);
    const halfHeight = Math.max(0.25, (max[1] - min[1]) / 2);
    const aroundY = Math.max(0.25, Math.hypot(max[0] - min[0], max[2] - min[2]) / 2);
    if (ground) addGround(model, Math.max(60, half * 8));

    const started = performance.now();
    const animated = !!spin || model.animated;
    let frameId = 0;
    let visible = true;

    const render = () => {
      const scaleFactor = Math.min(window.devicePixelRatio || 1, 2);
      const w = Math.max(1, Math.round(canvas.clientWidth * scaleFactor));
      const h = Math.max(1, Math.round(canvas.clientHeight * scaleFactor));
      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w;
        canvas.height = h;
      }
      const time = (performance.now() - started) / 1000;
      // Far enough back that the model fits from every side, so turning it never crops it or
      // changes its size on screen.
      const tanUp = Math.tan(FIELD_OF_VIEW / 2);
      const tanAcross = tanUp * (w / h);
      const tilt = look.current.pitch;
      const up = halfHeight * Math.cos(tilt) + aroundY * Math.abs(Math.sin(tilt));
      const fit = Math.max(aroundY / tanAcross, up / tanUp) + aroundY * 0.6;
      const distance = props.distance ?? fit * 1.02;
      const camera: Camera = {
        yaw: look.current.yaw + (spin && !look.current.dragged ? rad(spin) * time : 0),
        pitch: look.current.pitch,
        distance,
        target: props.target ?? middle,
      };
      look.current.shown = camera.yaw;
      const scene: Scene = {
        background: resolveColor(props.background, palette.mist),
        fogNear: distance * 1.8,
        fogFar: distance * 4.5,
        shadowRadius: Math.max(half * 1.6, 8),
      };
      drawModel(ctx, model, camera, scene, time, w, h);
    };
    draw.current = render;

    const tick = () => {
      if (visible) render();
      frameId = requestAnimationFrame(tick);
    };
    render();
    if (animated) frameId = requestAnimationFrame(tick);

    const resize = typeof ResizeObserver !== "undefined" ? new ResizeObserver(() => render()) : null;
    resize?.observe(canvas);
    const seen = typeof IntersectionObserver !== "undefined"
      ? new IntersectionObserver((entries) => {
          visible = entries[entries.length - 1].isIntersecting;
        })
      : null;
    seen?.observe(canvas);

    return () => {
      cancelAnimationFrame(frameId);
      resize?.disconnect();
      seen?.disconnect();
      draw.current = () => undefined;
      releaseModel(model);
    };
  }, [built, ground, spin, props.distance, props.target, props.background]);

  const dragFrom = useRef<[number, number] | null>(null);
  const dragHandlers = draggable
    ? {
        onPointerDown: (e: React.PointerEvent<HTMLCanvasElement>) => {
          dragFrom.current = [e.clientX, e.clientY];
          // Keep whatever angle the slow turn had reached.
          look.current.yaw = look.current.shown;
          look.current.dragged = true;
          e.currentTarget.setPointerCapture?.(e.pointerId);
        },
        onPointerMove: (e: React.PointerEvent<HTMLCanvasElement>) => {
          const from = dragFrom.current;
          if (!from) return;
          look.current.yaw -= (e.clientX - from[0]) * 0.008;
          look.current.pitch = clamp(look.current.pitch + (e.clientY - from[1]) * 0.006, -0.05, 1.45);
          dragFrom.current = [e.clientX, e.clientY];
          draw.current();
        },
        onPointerUp: () => {
          dragFrom.current = null;
        },
        onPointerCancel: () => {
          dragFrom.current = null;
        },
      }
    : {};

  const box: CSSProperties = { width, height, position: "relative", overflow: "hidden", ...props.style };
  if (built.error) {
    return (
      <div style={{ ...box, padding: 16, boxSizing: "border-box", background: "#3a2618", color: "#f5ebd2", fontFamily: "system-ui, sans-serif", fontSize: 14 }}>
        This model could not be built: {built.error}
      </div>
    );
  }
  return (
    <div style={box}>
      <canvas
        ref={canvasRef}
        role="img"
        aria-label={props.label ?? `3D model${props.name ? `: ${props.name}` : ""}`}
        style={{ display: "block", width: "100%", height: "100%", cursor: draggable ? "grab" : "default", touchAction: draggable ? "pan-y" : "auto" }}
        {...dragHandlers}
      />
    </div>
  );
}

markPiece(ModelStage, { kind: "stage" });
