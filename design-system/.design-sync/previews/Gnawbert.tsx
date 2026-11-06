import { Gnawbert } from "trees-with-teeth-3d";

/** Its mouth nearly shut, next to a player for size. */
export const Resting = () => <Gnawbert width={560} height={420} yaw={24} pitch={9} mouth={0.2} person />;

/** Wide open, waiting for logs. */
export const Hungry = () => <Gnawbert width={560} height={420} yaw={14} pitch={7} mouth={0.85} />;

/** Eating: it keeps snapping shut. */
export const Chomping = () => <Gnawbert width={560} height={420} yaw={-32} pitch={8} chomping />;

/** Its cut top, with rings, moss and the twig. */
export const FromBehind = () => <Gnawbert width={560} height={420} yaw={155} pitch={24} />;
