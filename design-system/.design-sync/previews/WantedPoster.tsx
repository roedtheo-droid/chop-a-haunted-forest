import { WantedPoster } from "trees-with-teeth-3d";

/** The grinning pine. */
export const Pine = () => <WantedPoster width={380} height={480} sketch="A" yaw={0} pitch={0} />;

/** The stump with its mouth open. */
export const Stump = () => <WantedPoster width={380} height={480} sketch="B" yaw={0} pitch={0} />;

/** The oak running away. */
export const Oak = () => <WantedPoster width={380} height={480} sketch="C" yaw={0} pitch={0} />;

/** Seen from the side, with no bars where the words go. */
export const NoWords = () => <WantedPoster width={380} height={480} sketch="A" yaw={28} pitch={6} words={false} />;
