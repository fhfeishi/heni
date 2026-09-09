import type { PlaybackPort } from "../contracts/playback";
import { ok } from "../contracts/result";

// Static test ports may answer conditional reads with a complete snapshot.
export const playbackReader = (
  readSnapshot: PlaybackPort["readSnapshot"],
): Pick<PlaybackPort, "readSnapshot" | "readUpdate"> => ({
  readSnapshot,
  async readUpdate() {
    const result = await readSnapshot();
    return result.ok
      ? ok({ type: "snapshot", snapshot: result.value })
      : result;
  },
});
