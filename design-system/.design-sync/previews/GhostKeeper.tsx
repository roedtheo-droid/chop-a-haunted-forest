import { GhostKeeper } from "trees-with-teeth-3d";

/** Its face, with spectacles, a mustache and a bowler hat. */
export const Front = () => <GhostKeeper width={480} height={520} yaw={0} pitch={0} />;

/** Next to a player, to show its size. */
export const WithPerson = () => <GhostKeeper width={480} height={520} yaw={14} pitch={6} person />;

/** Behind the counter, the way players see it, bobbing up and down. */
export const AtTheCounter = () => <GhostKeeper width={480} height={520} yaw={-28} pitch={8} counter floating />;

/** The bow that ties its apron, showing through from behind. */
export const FromBehind = () => <GhostKeeper width={480} height={520} yaw={160} pitch={8} />;
