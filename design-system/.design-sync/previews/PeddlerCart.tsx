import { PeddlerCart } from "trees-with-teeth-3d";

/** Next to a player, to show its size. */
export const WithPerson = () => <PeddlerCart width={560} height={420} yaw={24} pitch={10} person />;

/** The side that sells: the hanging sign, the sack, the coins and the crates. */
export const Front = () => <PeddlerCart width={560} height={420} yaw={0} pitch={4} />;

/** From above, with the handles resting on a little log. */
export const FromAbove = () => <PeddlerCart width={560} height={420} yaw={-35} pitch={24} />;

/** From behind, with its plank back and the wooden beams under the canvas. */
export const FromBehind = () => <PeddlerCart width={560} height={420} yaw={150} pitch={12} />;
