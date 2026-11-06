import { Ghost } from "trees-with-teeth-3d";

/** Its face, with long eyes and an "O" mouth. */
export const Front = () => <Ghost width={480} height={400} yaw={-20} pitch={0} />;

/** Next to a player, to show how small it is. */
export const WithPerson = () => <Ghost width={480} height={400} yaw={24} pitch={6} person />;

/** Bobbing up and down, the way it floats in the game. */
export const Floating = () => <Ghost width={480} height={400} yaw={40} pitch={4} floating />;

/** Its face shows faintly through its back. */
export const FromBehind = () => <Ghost width={480} height={400} yaw={150} pitch={10} />;
