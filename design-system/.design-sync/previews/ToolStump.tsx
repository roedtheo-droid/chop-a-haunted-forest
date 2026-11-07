import { ToolStump } from "trees-with-teeth-3d";

/** Dressed the way the game does it, next to a player for size. */
export const Dressed = () => <ToolStump width={480} height={520} yaw={24} pitch={10} person />;

/** The stump alone: this is what goes to Roblox. */
export const Bare = () => <ToolStump width={480} height={520} yaw={-30} pitch={16} dressed={false} />;

/** From behind, with the post tied to the stump by an iron band. */
export const FromBehind = () => <ToolStump width={480} height={520} yaw={150} pitch={14} dressed={false} />;
