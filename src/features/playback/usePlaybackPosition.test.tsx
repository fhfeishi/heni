import { act, cleanup, renderHook } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type { PlaybackClockSample } from "./application/playbackClock";
import { usePlaybackPosition } from "./usePlaybackPosition";

const sample: PlaybackClockSample = {
  generation: 1,
  sequence: 1,
  mediaId: "one",
  status: "playing",
  positionMs: 2_000,
  durationMs: 60_000,
  sampledAtMs: 0,
};

const frames = new Map<number, FrameRequestCallback>();
const advanceFrame = (nowMs: number) => {
  const pending = [...frames.values()];
  frames.clear();
  act(() => {
    for (const callback of pending) callback(nowMs);
  });
};

beforeEach(() => {
  let id = 0;
  frames.clear();
  vi.spyOn(document, "hidden", "get").mockReturnValue(false);
  vi.spyOn(window, "requestAnimationFrame").mockImplementation((callback) => {
    frames.set(++id, callback);
    return id;
  });
  vi.spyOn(window, "cancelAnimationFrame").mockImplementation((requestId) => {
    frames.delete(requestId);
  });
});
afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

describe("usePlaybackPosition", () => {
  it("publishes only local display frames and stops after its extrapolation budget", () => {
    const { result } = renderHook(() => usePlaybackPosition(sample));
    expect(result.current).toBe(2_000);
    advanceFrame(100);
    expect(result.current).toBe(2_100);
    advanceFrame(116);
    expect(result.current).toBe(2_100);
    advanceFrame(132);
    expect(result.current).toBe(2_132);
    advanceFrame(750);
    expect(result.current).toBe(2_750);
    expect(frames.size).toBe(0);
  });

  it("immediately replaces a previous track frame and ignores a late callback", () => {
    const { result, rerender } = renderHook(
      ({ value }) => usePlaybackPosition(value),
      { initialProps: { value: sample } },
    );
    advanceFrame(200);
    const oldCallback = [...frames.values()][0];
    if (oldCallback === undefined)
      throw new Error("Expected an animation callback.");
    rerender({
      value: {
        ...sample,
        generation: 2,
        mediaId: "two",
        positionMs: 7_000,
        sampledAtMs: 200,
      },
    });
    expect(result.current).toBe(7_000);
    act(() => oldCallback(250));
    expect(result.current).toBe(7_000);
    advanceFrame(300);
    expect(result.current).toBe(7_100);
  });

  it("keeps a backwards seek and pause authoritative", () => {
    const { result, rerender } = renderHook(
      ({ value }) => usePlaybackPosition(value),
      { initialProps: { value: sample } },
    );
    advanceFrame(200);
    rerender({
      value: { ...sample, sequence: 2, positionMs: 500, sampledAtMs: 200 },
    });
    expect(result.current).toBe(500);
    advanceFrame(300);
    expect(result.current).toBe(600);
    rerender({
      value: {
        ...sample,
        sequence: 3,
        status: "paused",
        positionMs: 630,
        sampledAtMs: 330,
      },
    });
    expect(result.current).toBe(630);
    expect(frames.size).toBe(0);
  });

  it("does not schedule frames for empty, paused or suspended controls", () => {
    const { result, rerender } = renderHook(
      ({ suspended }) => usePlaybackPosition(sample, suspended),
      { initialProps: { suspended: true } },
    );
    expect(result.current).toBe(2_000);
    expect(frames.size).toBe(0);
    rerender({ suspended: false });
    expect(frames.size).toBe(1);
    rerender({ suspended: true });
    expect(frames.size).toBe(0);
    renderHook(() => usePlaybackPosition(null));
    renderHook(() => usePlaybackPosition({ ...sample, status: "paused" }));
    expect(frames.size).toBe(0);
  });

  it("cancels hidden-window work and never counts the whole hidden interval as audio", () => {
    const { result } = renderHook(() => usePlaybackPosition(sample));
    advanceFrame(100);
    vi.spyOn(document, "hidden", "get").mockReturnValue(true);
    act(() => document.dispatchEvent(new Event("visibilitychange")));
    expect(frames.size).toBe(0);
    expect(result.current).toBe(2_100);
    vi.spyOn(document, "hidden", "get").mockReturnValue(false);
    act(() => document.dispatchEvent(new Event("visibilitychange")));
    advanceFrame(60_000);
    expect(result.current).toBe(2_750);
    expect(frames.size).toBe(0);
  });

  it("cancels the pending frame and visibility listener on unmount", () => {
    const { unmount } = renderHook(() => usePlaybackPosition(sample));
    expect(frames.size).toBe(1);
    unmount();
    expect(frames.size).toBe(0);
    act(() => document.dispatchEvent(new Event("visibilitychange")));
    expect(frames.size).toBe(0);
  });
});
