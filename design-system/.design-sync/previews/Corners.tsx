import { Block, Corners, ModelPart, ModelStage, Place } from "trees-with-teeth-3d";
import type { Vec3 } from "trees-with-teeth-3d";

const ROOT: Vec3[] = [
  [-1, 0, 0], [1, 0, 0], [-1, 2, 0], [1, 2, 0],
  [-0.3, 0, 4], [0.3, 0, 4], [-0.2, 0.3, 4], [0.2, 0.3, 4],
];

/** A root that hugs the ground as it spreads out. */
export const Root = () => (
  <ModelStage width={420} height={280} yaw={60}>
    <ModelPart name="Root" color="root">
      <Corners points={ROOT} bevel={0.14} />
    </ModelPart>
  </ModelStage>
);

/** A stump cut at a slant, with roots placed around it. */
export const SlantedStump = () => (
  <ModelStage width={420} height={300}>
    <ModelPart name="Trunk" color="bark">
      <Corners
        bevel={0.3}
        points={[
          [-3, 0, -3], [3, 0, -3], [-2.5, 3, -2.5], [2.5, 4.4, -2.5],
          [-3, 0, 3], [3, 0, 3], [-2.5, 3.6, 2.5], [2.5, 5, 2.5],
        ]}
      />
    </ModelPart>
    <ModelPart name="Root" color="root">
      {[40, 130, 220, 310].map((angle) => (
        <Place key={angle} at={[Math.sin((angle * Math.PI) / 180) * 2.6, 0, Math.cos((angle * Math.PI) / 180) * 2.6]} turn={[0, angle, 0]}>
          <Corners points={ROOT} bevel={0.14} />
        </Place>
      ))}
    </ModelPart>
  </ModelStage>
);

/** A wedge door stop made by hand, next to a block for comparison. */
export const Wedge = () => (
  <ModelStage width={420} height={280} background="edge" ground={false}>
    <ModelPart name="Wedge" color="plank">
      <Corners
        points={[
          [-1.5, 0, -2], [1.5, 0, -2], [-1.5, 2, -2], [1.5, 2, -2],
          [-1.5, 0, 2], [1.5, 0, 2], [-1.5, 0.15, 2], [1.5, 0.15, 2],
        ]}
      />
    </ModelPart>
    <ModelPart name="Block" color="plankDark">
      <Block size={[2, 2, 2]} at={[3.5, 0, 0]} standing />
    </ModelPart>
  </ModelStage>
);
