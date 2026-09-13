import { afterEach, describe, expect, it, vi } from "vitest";
import { VolumeGesture } from "./volumeGesture";
import type { PlaybackCommand, PlaybackSnapshot } from "../../../contracts/playback";

const snapshot: PlaybackSnapshot = { generation: 2, sequence: 3, status: "idle", queue: [], currentIndex: null,
  positionMs: 0, durationMs: null, volume: 70, muted: false, repeatMode: "all", shuffle: false };
const deferred = () => {
  let resolve: (value: boolean) => void = () => { throw new Error("Deferred result was not initialized."); };
  const promise = new Promise<boolean>((done) => { resolve = done; });
  return { promise, resolve };
};
afterEach(() => vi.useRealTimers());

describe("volume gesture", () => {
  it("coalesces movement behind one request and submits the last target once", async () => {
    vi.useFakeTimers();
    const first = deferred();
    const dispatch = vi.fn<(command: PlaybackCommand) => Promise<boolean>>().mockReturnValueOnce(first.promise).mockResolvedValue(true);
    const gesture = new VolumeGesture(snapshot, dispatch, vi.fn());
    gesture.stage(30);
    await vi.advanceTimersByTimeAsync(40);
    gesture.stage(42);
    gesture.stage(55);
    await vi.advanceTimersByTimeAsync(100);
    expect(dispatch).toHaveBeenCalledTimes(1);
    const finished = gesture.finish(true);
    expect(gesture.finish(true)).toBe(finished);
    first.resolve(true);
    expect(await finished).toBe(true);
    expect(dispatch.mock.calls.map(([command]) => command.type)).toEqual(["preview-volume", "preview-volume", "commit-volume-preview"]);
    expect(dispatch).toHaveBeenLastCalledWith({ type: "commit-volume-preview", volume: 55, generation: 2, sequence: 3, gestureId: gesture.gestureId });
    await vi.advanceTimersByTimeAsync(3000);
    expect(dispatch).toHaveBeenCalledTimes(3);
  });

  it("cancels after an in-flight preview without saving or replaying queued targets", async () => {
    vi.useFakeTimers();
    const first = deferred();
    const dispatch = vi.fn<(command: PlaybackCommand) => Promise<boolean>>().mockReturnValueOnce(first.promise).mockResolvedValue(true);
    const gesture = new VolumeGesture(snapshot, dispatch, vi.fn());
    gesture.stage(20);
    await vi.advanceTimersByTimeAsync(40);
    gesture.stage(90);
    const cancelled = gesture.finish(false);
    first.resolve(true);
    await cancelled;
    await vi.advanceTimersByTimeAsync(3000);
    expect(dispatch.mock.calls.map(([command]) => command.type)).toEqual(["preview-volume", "cancel-volume-preview"]);
  });

  it("renews a stationary drag and cancels a failed preview without committing", async () => {
    vi.useFakeTimers();
    const failure = vi.fn();
    const dispatch = vi.fn<(command: PlaybackCommand) => Promise<boolean>>().mockResolvedValueOnce(true).mockResolvedValueOnce(false).mockResolvedValue(true);
    const gesture = new VolumeGesture(snapshot, dispatch, failure);
    gesture.stage(30);
    await vi.advanceTimersByTimeAsync(600);
    expect(dispatch.mock.calls.map(([command]) => command.type)).toEqual(["preview-volume", "preview-volume", "cancel-volume-preview"]);
    expect(failure).toHaveBeenCalledOnce();
    await gesture.finish(true);
    expect(dispatch).toHaveBeenCalledTimes(3);
  });

  it("cleans up a failed commit and handles rejected transports", async () => {
    const dispatch = vi.fn<(command: PlaybackCommand) => Promise<boolean>>().mockResolvedValueOnce(true).mockRejectedValueOnce(new Error("offline")).mockResolvedValue(true);
    const gesture = new VolumeGesture(snapshot, dispatch, vi.fn());
    gesture.stage(50);
    expect(await gesture.finish(true)).toBe(false);
    expect(dispatch.mock.calls.map(([command]) => command.type)).toEqual(["preview-volume", "commit-volume-preview", "cancel-volume-preview"]);
  });
});
