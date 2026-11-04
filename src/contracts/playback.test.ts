import { describe, expect, it } from "vitest";

import {
  playbackCommandSchema,
  playbackSnapshotSchema,
  playbackUpdateSchema,
} from "./playback";
import playbackCommandFixtures from "../../fixtures/playback/commands.json";
import playbackUpdateFixtures from "../../fixtures/playback/updates.json";

const emptySnapshot = {
  generation: 0,
  sequence: 0,
  status: "idle",
  queue: [],
  currentIndex: null,
  positionMs: 0,
  durationMs: null,
  volume: 100,
  muted: false,
  repeatMode: "all",
  shuffle: false,
} as const;

describe("playbackSnapshotSchema", () => {
  it("accepts a finite optional warning while keeping volume and mute authoritative", () => {
    expect(
      playbackSnapshotSchema.safeParse({
        ...emptySnapshot,
        volume: 0,
        muted: true,
        preferencesError: {
          code: "preferences-unavailable",
          message: "cannot restore",
        },
      }).success,
    ).toBe(true);
    expect(
      playbackSnapshotSchema.safeParse({
        ...emptySnapshot,
        preferencesError: { code: "unexpected-error", message: "private" },
      }).success,
    ).toBe(false);
  });

  it("accepts a valid idle snapshot", () => {
    expect(playbackSnapshotSchema.safeParse(emptySnapshot).success).toBe(true);
  });

  it("rejects an index outside the queue", () => {
    const result = playbackSnapshotSchema.safeParse({
      ...emptySnapshot,
      queue: [
        {
          id: "track-1",
          path: "C:\\Music\\one.flac",
          title: "one",
          kind: "audio",
          durationMs: 1_000,
        },
      ],
      currentIndex: 1,
      status: "paused",
    });

    expect(result.success).toBe(false);
  });

  it("rejects a projected next index outside the queue", () => {
    const result = playbackSnapshotSchema.safeParse({
      ...emptySnapshot,
      queue: [
        {
          id: "track-1",
          path: "C:\\Music\\one.flac",
          title: "one",
          kind: "audio",
          durationMs: 1_000,
        },
      ],
      currentIndex: 0,
      nextIndex: 1,
      status: "playing",
    });

    expect(result.success).toBe(false);
  });
});

describe("playbackCommandSchema", () => {
  it("accepts every shared TypeScript-Rust IPC command fixture", () => {
    for (const command of playbackCommandFixtures) {
      expect(playbackCommandSchema.safeParse(command).success).toBe(true);
    }
  });

  it("rejects volume outside the public contract", () => {
    const result = playbackCommandSchema.safeParse({
      type: "set-volume",
      volume: 101,
    });

    expect(result.success).toBe(false);
  });

  it("requires a current item for a non-empty queue", () => {
    const result = playbackCommandSchema.safeParse({
      type: "replace-queue",
      queue: [
        {
          id: "track-1",
          path: "C:\\Music\\one.flac",
          title: "one",
          kind: "audio",
          durationMs: null,
        },
      ],
      currentIndex: null,
      autoplay: false,
    });

    expect(result.success).toBe(false);
  });

  it("rejects negative indexes for an authoritative queue reorder", () => {
    const result = playbackCommandSchema.safeParse({
      type: "reorder-queue",
      fromIndex: -1,
      toIndex: 0,
    });

    expect(result.success).toBe(false);
  });

  it("rejects duplicate Windows paths regardless of slash or case", () => {
    const result = playbackCommandSchema.safeParse({
      type: "replace-queue",
      queue: [
        {
          id: "track-1",
          path: "C:\\Music\\one.flac",
          title: "one",
          kind: "audio",
          durationMs: null,
        },
        {
          id: "track-2",
          path: "c:/music/ONE.flac",
          title: "duplicate",
          kind: "audio",
          durationMs: null,
        },
      ],
      currentIndex: 0,
      autoplay: true,
    });

    expect(result.success).toBe(false);
  });
});

describe("playbackUpdateSchema", () => {
  it("accepts the exact updates serialized by the Rust fixture test", () => {
    for (const update of playbackUpdateFixtures) {
      expect(playbackUpdateSchema.safeParse(update).success).toBe(true);
    }
  });

  it.each([
    {
      type: "position",
      position: { generation: 1, sequence: 0, positionMs: 4 },
    },
    {
      type: "position",
      position: {
        generation: 1,
        sequence: 0,
        positionMs: -1,
        status: "playing",
        mediaId: "one",
        durationMs: 5,
      },
    },
    { type: "snapshot", snapshot: { ...emptySnapshot, currentIndex: 0 } },
    { type: "track-ended", generation: 1, sequence: 1, mediaId: "one" },
  ])("rejects incomplete or obsolete update payloads: %j", (value) => {
    expect(playbackUpdateSchema.safeParse(value).success).toBe(false);
  });
});
