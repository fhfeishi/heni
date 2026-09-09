import { describe, expect, it, vi } from "vitest";

import { createPlaybackPort } from "./playbackPort";

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

describe("createPlaybackPort", () => {
  it("keeps invoke details out of playback callers", async () => {
    const invoke = vi.fn().mockResolvedValue(emptySnapshot);
    const port = createPlaybackPort(invoke);

    await expect(port.dispatch({ type: "play" })).resolves.toEqual({
      ok: true,
      value: emptySnapshot,
    });
    expect(invoke).toHaveBeenCalledWith("playback_dispatch", {
      command: { type: "play" },
    });
  });

  it("maps a Rust command error without throwing into React", async () => {
    const invoke = vi.fn().mockRejectedValue({
      code: "empty-queue",
      message: "Cannot play an empty queue.",
    });
    const port = createPlaybackPort(invoke);

    await expect(port.dispatch({ type: "play" })).resolves.toEqual({
      ok: false,
      error: {
        code: "empty-queue",
        message: "Cannot play an empty queue.",
      },
    });
  });

  it("passes only the known state version for conditional polling", async () => {
    const update = {
      type: "position",
      position: {
        generation: 2,
        sequence: 4,
        status: "playing",
        mediaId: "one",
        positionMs: 300,
        durationMs: 60_000,
      },
    };
    const invoke = vi.fn().mockResolvedValue(update);
    const port = createPlaybackPort(invoke);
    await expect(
      port.readUpdate({ generation: 2, sequence: 4 }),
    ).resolves.toEqual({ ok: true, value: update });
    expect(invoke).toHaveBeenCalledWith("playback_poll", {
      knownVersion: { generation: 2, sequence: 4 },
    });
  });

  it("accepts a full response after Rust changes the session", async () => {
    const update = { type: "snapshot", snapshot: emptySnapshot };
    const port = createPlaybackPort(vi.fn().mockResolvedValue(update));
    await expect(
      port.readUpdate({ generation: 2, sequence: 4 }),
    ).resolves.toEqual({ ok: true, value: update });
  });

  it("rejects malformed position responses and handles transport failures", async () => {
    const invoke = vi
      .fn()
      .mockResolvedValueOnce({ type: "position", position: { positionMs: 10 } })
      .mockRejectedValueOnce({
        code: "internal",
        message: "temporarily unavailable",
      });
    const port = createPlaybackPort(invoke);
    await expect(
      port.readUpdate({ generation: 1, sequence: 0 }),
    ).resolves.toMatchObject({
      ok: false,
      error: { code: "invalid-contract" },
    });
    await expect(
      port.readUpdate({ generation: 1, sequence: 0 }),
    ).resolves.toMatchObject({ ok: false, error: { code: "internal" } });
  });
});
