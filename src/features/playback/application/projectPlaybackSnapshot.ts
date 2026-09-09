import type { PlaybackSnapshot } from "../../../contracts/playback";

export const projectPlaybackSnapshot = (
  current: PlaybackSnapshot | null,
  incoming: PlaybackSnapshot,
): PlaybackSnapshot => {
  if (current === null) {
    return incoming;
  }

  const isOlderGeneration = incoming.generation < current.generation;
  const isOlderSequence =
    incoming.generation === current.generation &&
    incoming.sequence < current.sequence;

  return isOlderGeneration || isOlderSequence ? current : incoming;
};
