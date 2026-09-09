import { describe, expect, it } from "vitest";
import type {
  PlaybackPosition,
  PlaybackSnapshot,
} from "../../../contracts/playback";
import { projectPlaybackPosition } from "./projectPlaybackPosition";

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
  volume: 80,
  muted: false,
  repeatMode: "all",
  shuffle: false,
};
const sample: PlaybackPosition = {
  generation: 4,
  sequence: 8,
  status: "playing",
  mediaId: "one",
  positionMs: 3_250,
  durationMs: 60_000,
};

describe("projectPlaybackPosition", () => {
  it("updates time without changing the state version or copying the queue", () => {
    const next = projectPlaybackPosition(snapshot, sample);
    expect(next).toEqual({ ...snapshot, positionMs: 3_250 });
    expect(next?.queue).toBe(snapshot.queue);
  });

  it.each<Partial<PlaybackPosition>>([
    { generation: 3 },
    { generation: 5 },
    { sequence: 7 },
    { sequence: 9 },
    { mediaId: "two" },
    { mediaId: null },
    { status: "paused" },
  ])(
    "ignores a sample that does not match the known state: %j",
    (difference) => {
      expect(
        projectPlaybackPosition(snapshot, { ...sample, ...difference }),
      ).toBe(snapshot);
    },
  );

  it("never constructs a queue from a position-only response", () => {
    expect(projectPlaybackPosition(null, sample)).toBeNull();
  });

  it("accepts a newly discovered duration and clamps its position", () => {
    expect(
      projectPlaybackPosition(snapshot, { ...sample, durationMs: 3_000 }),
    ).toMatchObject({ positionMs: 3_000, durationMs: 3_000, sequence: 8 });
  });

  it("accepts idle samples without inventing a media item", () => {
    const idle = {
      ...snapshot,
      status: "idle" as const,
      currentIndex: null,
      queue: [],
    };
    expect(
      projectPlaybackPosition(idle, {
        ...sample,
        status: "idle",
        mediaId: null,
        positionMs: 0,
        durationMs: null,
      }),
    ).toEqual({ ...idle, positionMs: 0, durationMs: null });
  });
});
