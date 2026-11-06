// 3D Roblox tools modeling: everything a design can use.

export { ModelStage } from "./stage/ModelStage";
export type { ModelStageProps } from "./stage/ModelStage";
export { ModelPart } from "./structure/ModelPart";
export type { ModelPartProps } from "./structure/ModelPart";
export { MovingGroup } from "./structure/MovingGroup";
export type { MovingGroupProps } from "./structure/MovingGroup";
export { Place } from "./structure/Place";
export type { PlaceProps } from "./structure/Place";
export { Block } from "./shapes/Block";
export type { BlockProps } from "./shapes/Block";
export { Chain } from "./shapes/Chain";
export type { ChainProps } from "./shapes/Chain";
export { Corners } from "./shapes/Corners";
export type { CornersProps } from "./shapes/Corners";
export { Prism } from "./shapes/Prism";
export type { PrismProps } from "./shapes/Prism";
export { Skin } from "./shapes/Skin";
export type { SkinProps } from "./shapes/Skin";
export { Tooth } from "./shapes/Tooth";
export type { ToothProps } from "./shapes/Tooth";
export { Ghost } from "./models/Ghost";
export type { GhostProps } from "./models/Ghost";
export { Gnawbert } from "./models/Gnawbert";
export type { GnawbertProps } from "./models/Gnawbert";

export { collectModel } from "./core/collect";
export { toGltf } from "./core/gltf";
export { palette } from "./core/palette";
export type { Color, PaletteName, Rgb } from "./core/palette";
export type { SkinRing } from "./core/shapes";
export type { Vec3 } from "./core/math";
