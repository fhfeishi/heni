import { describe, expect, it } from "vitest";

import type { PlaybackSnapshot } from "../../../contracts/playback";
import { projectPlaybackSnapshot } from "./projectPlaybackSnapshot";

const snapshot: PlaybackSnapshot = {
  generation: 4,
  sequence: 8,
  status: "playing",
  queue: [
    {
      id: "track-1",
      path: "C:\\Music\\one.flac",
      title: "one",
      kind: "audio",
      durationMs: 60_000,
    },
  ],
  currentIndex: 0,
  positionMs: 2_000,
  durationMs: 60_000,
  volume: 80,
  muted: false,
  repeatMode: "all",
  shuffle: false,
};

describe("projectPlaybackSnapshot", () => {
  it("ignores a late snapshot from an older media generation", () => {
    const result = projectPlaybackSnapshot(snapshot, {
      ...snapshot,
      generation: 3,
      sequence: 99,
      positionMs: 50_000,
    });

    expect(result).toBe(snapshot);
  });

  it("ignores an out-of-order snapshot in the active generation", () => {
    const result = projectPlaybackSnapshot(snapshot, {
      ...snapshot,
      sequence: 7,
      status: "paused",
    });

    expect(result).toBe(snapshot);
  });

  it("accepts equal-sequence polling snapshots so position can advance", () => {
    const incoming = {
      ...snapshot,
      positionMs: 3_250,
    };

    expect(projectPlaybackSnapshot(snapshot, incoming)).toBe(incoming);
  });
});
