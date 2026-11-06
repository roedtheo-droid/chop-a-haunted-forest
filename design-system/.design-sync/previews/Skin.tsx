import { ModelPart, ModelStage, Skin } from "trees-with-teeth-3d";

const SHEET = [
  { y: 1.45, width: 0.55 },
  { y: 1.25, width: 1.05 },
  { y: 0.2, width: 1.32 },
  { y: -1.2, width: 1.42 },
  { y: -2.05, width: 1.7, wave: 0.3 },
  { y: -1.72, width: 1.2 },
];

/** A sheet with a wavy hem, see-through like a ghost. */
export const Sheet = () => (
  <ModelStage width={420} height={300}>
    <ModelPart name="Body" color="ghost" alpha={0.85}>
      <Skin rings={SHEET} sides={24} at={[0, 3.2, 0]} />
    </ModelPart>
  </ModelStage>
);

/** `squareness` 2 is an oval. */
export const Round = () => (
  <ModelStage width={420} height={300}>
    <ModelPart name="Body" color="pine">
      <Skin rings={SHEET} sides={24} squareness={2} at={[0, 3.2, 0]} />
    </ModelPart>
  </ModelStage>
);

/** A high `squareness` is nearly a box. */
export const Boxy = () => (
  <ModelStage width={420} height={300}>
    <ModelPart name="Body" color="plank">
      <Skin rings={SHEET} sides={24} squareness={7} at={[0, 3.2, 0]} />
    </ModelPart>
  </ModelStage>
);
