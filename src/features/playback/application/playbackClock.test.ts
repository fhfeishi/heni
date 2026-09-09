import { describe, expect, it } from "vitest";

import type {
  PlaybackSnapshot,
  PlaybackStatus,
} from "../../../contracts/playback";
import {
  createPlaybackClockSample,
  projectPlaybackClock,
  type PlaybackClockSample,
} from "./playbackClock";

const sample: PlaybackClockSample = {
  generation: 4,
  sequence: 8,
  mediaId: "one",
  status: "playing",
  positionMs: 2_000,
  durationMs: 60_000,
  sampledAtMs: 1_000,
};

describe("playback clock projection", () => {
  it("interpolates from a monotonic timestamp without changing the sample", () => {
    expect(projectPlaybackClock(sample, 1_240.75)).toEqual({
      positionMs: 2_240,
      advancing: true,
    });
    expect(sample.positionMs).toBe(2_000);
    expect(sample.status).toBe("playing");
  });

  it.each<PlaybackStatus>([
    "idle",
    "loading",
    "paused",
    "stopped",
    "completed",
    "failed",
  ])("never extrapolates a %s sample", (status) => {
    expect(projectPlaybackClock({ ...sample, status }, 1_500)).toEqual({
      positionMs: 2_000,
      advancing: false,
    });
  });

  it("bounds an IPC stall or a long suspension to 750 ms", () => {
    expect(projectPlaybackClock(sample, 80_000)).toEqual({
      positionMs: 2_750,
      advancing: false,
    });
  });

  it("clamps to duration without declaring the track completed", () => {
    expect(
      projectPlaybackClock({ ...sample, positionMs: 59_900 }, 1_500),
    ).toEqual({ positionMs: 60_000, advancing: false });
    expect(sample.status).toBe("playing");
    expect(projectPlaybackClock({ ...sample, durationMs: 0 }, 1_500)).toEqual({
      positionMs: 0,
      advancing: false,
    });
  });

  it("handles a missing duration, empty state and a timestamp before the sample", () => {
    expect(
      projectPlaybackClock({ ...sample, durationMs: null }, 1_200).positionMs,
    ).toBe(2_200);
    expect(projectPlaybackClock(null, 1_200)).toEqual({
      positionMs: 0,
      advancing: false,
    });
    expect(projectPlaybackClock(sample, 900).positionMs).toBe(2_000);
  });

  it("accepts a backwards seek or a new track as a new anchor", () => {
    expect(
      projectPlaybackClock(
        { ...sample, sequence: 9, positionMs: 100, sampledAtMs: 1_500 },
        1_600,
      ).positionMs,
    ).toBe(200);
    expect(
      projectPlaybackClock(
        {
          ...sample,
          generation: 5,
          sequence: 0,
          mediaId: "two",
          positionMs: 0,
          sampledAtMs: 1_500,
        },
        1_600,
      ).positionMs,
    ).toBe(100);
  });

  it("extracts only display fields and the selected media identity", () => {
    const snapshot: PlaybackSnapshot = {
      generation: 4,
      sequence: 8,
      status: "playing",
      currentIndex: 0,
      queue: [
        {
          id: "one",
          path: "C:/one.flac",
          title: "one",
          kind: "audio",
          durationMs: 60_000,
        },
      ],
      positionMs: 2_000,
      durationMs: 60_000,
      volume: 70,
      muted: false,
      repeatMode: "all",
      shuffle: false,
    };
    expect(createPlaybackClockSample(snapshot, 1_000)).toEqual(sample);
    expect(
      createPlaybackClockSample({ ...snapshot, currentIndex: null }, 1_000),
    ).toBeNull();
  });
});
