import type {
  PlaybackPosition,
  PlaybackSnapshot,
} from "../../../contracts/playback";

export const projectPlaybackPosition = (
  snapshot: PlaybackSnapshot | null,
  position: PlaybackPosition,
): PlaybackSnapshot | null => {
  if (snapshot === null) return snapshot;
  const mediaId =
    snapshot.currentIndex === null
      ? null
      : snapshot.queue[snapshot.currentIndex]?.id;
  if (
    position.generation !== snapshot.generation ||
    position.sequence !== snapshot.sequence ||
    position.status !== snapshot.status ||
    position.mediaId !== mediaId
  )
    return snapshot;

  return {
    ...snapshot,
    positionMs:
      position.durationMs === null
        ? position.positionMs
        : Math.min(position.positionMs, position.durationMs),
    durationMs: position.durationMs,
  };
};
