import { useEffect, useState } from "react";

import {
  projectPlaybackClock,
  type PlaybackClockSample,
} from "./application/playbackClock";

interface DisplayFrame {
  readonly sample: PlaybackClockSample;
  readonly positionMs: number;
}

export const usePlaybackPosition = (
  sample: PlaybackClockSample | null,
  suspended = false,
): number => {
  const [frame, setFrame] = useState<DisplayFrame | null>(null);

  useEffect(() => {
    if (sample === null || sample.status !== "playing" || suspended) return;
    let active = true;
    let requestId: number | null = null;
    let lastPublishedAtMs = Number.NEGATIVE_INFINITY;

    const animate = (nowMs: number) => {
      requestId = null;
      if (!active || document.hidden) return;
      const projection = projectPlaybackClock(sample, nowMs);
      // Only this small control renders at animation cadence, capped near 30 Hz.
      if (nowMs - lastPublishedAtMs >= 32 || !projection.advancing) {
        lastPublishedAtMs = nowMs;
        setFrame({ sample, positionMs: projection.positionMs });
      }
      if (projection.advancing)
        requestId = window.requestAnimationFrame(animate);
    };

    const onVisibilityChange = () => {
      if (requestId !== null) window.cancelAnimationFrame(requestId);
      requestId = document.hidden
        ? null
        : window.requestAnimationFrame(animate);
    };
    onVisibilityChange();
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () => {
      active = false;
      if (requestId !== null) window.cancelAnimationFrame(requestId);
      document.removeEventListener("visibilitychange", onVisibilityChange);
    };
  }, [sample, suspended]);

  return !suspended && frame !== null && frame.sample === sample
    ? frame.positionMs
    : (sample?.positionMs ?? 0);
};
