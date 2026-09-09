import type {
  PlaybackSnapshot,
  PlaybackStatus,
} from "../../../contracts/playback";

// A short display-only bridge between authoritative samples, never a playback timer.
export const PLAYBACK_EXTRAPOLATION_LIMIT_MS = 750;

export interface PlaybackClockSample {
  readonly generation: number;
  readonly sequence: number;
  readonly mediaId: string;
  readonly status: PlaybackStatus;
  readonly positionMs: number;
  readonly durationMs: number | null;
  readonly sampledAtMs: number;
}

export const createPlaybackClockSample = (
  snapshot: PlaybackSnapshot,
  sampledAtMs: number,
): PlaybackClockSample | null => {
  const item =
    snapshot.currentIndex === null
      ? undefined
      : snapshot.queue[snapshot.currentIndex];
  return item === undefined
    ? null
    : {
        generation: snapshot.generation,
        sequence: snapshot.sequence,
        mediaId: item.id,
        status: snapshot.status,
        positionMs: snapshot.positionMs,
        durationMs: snapshot.durationMs,
        sampledAtMs,
      };
};

export const projectPlaybackClock = (
  sample: PlaybackClockSample | null,
  nowMs: number,
): Readonly<{ positionMs: number; advancing: boolean }> => {
  if (sample === null) return { positionMs: 0, advancing: false };

  const elapsedMs = Math.max(0, nowMs - sample.sampledAtMs);
  const deltaMs =
    sample.status === "playing"
      ? Math.min(elapsedMs, PLAYBACK_EXTRAPOLATION_LIMIT_MS)
      : 0;
  const positionMs = Math.floor(
    Math.max(
      0,
      Math.min(
        sample.positionMs + deltaMs,
        sample.durationMs ?? Number.MAX_SAFE_INTEGER,
      ),
    ),
  );
  return {
    positionMs,
    advancing:
      sample.status === "playing" &&
      elapsedMs < PLAYBACK_EXTRAPOLATION_LIMIT_MS &&
      (sample.durationMs === null || positionMs < sample.durationMs),
  };
};
