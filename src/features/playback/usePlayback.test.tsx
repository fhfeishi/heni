import { act, cleanup, renderHook } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type {
  PlaybackError,
  PlaybackPort,
  PlaybackSnapshot,
  PlaybackUpdate,
} from "../../contracts/playback";
import { err, ok, type Result } from "../../contracts/result";
import { usePlayback } from "./usePlayback";
import { playbackReader } from "../../test/playbackReader";

const snapshot: PlaybackSnapshot = {
  generation: 1,
  sequence: 1,
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
type PlaybackResult = Result<PlaybackSnapshot, PlaybackError>;
const failure: PlaybackError = { code: "transport", message: "unavailable" };
const deferred = <Value,>() => {
  let settle: ((value: Value) => void) | undefined;
  const promise = new Promise<Value>((resolve) => {
    settle = resolve;
  });
  return {
    promise,
    resolve(value: Value) {
      if (settle === undefined)
        throw new Error("Deferred result was not initialized.");
      settle(value);
    },
  };
};
const source = (): PlaybackPort => ({
  ...playbackReader(async () => ok(snapshot)),
  dispatch: async () => ok(snapshot),
});

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe("usePlayback", () => {
  it("keeps a command failure visible across successful reads until dismissed", async () => {
    const port = { ...source(), dispatch: async () => err(failure) };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => undefined);
    await act(async () => {
      await result.current.dispatch({ type: "set-volume", volume: 30 });
    });
    await act(async () => {
      await vi.advanceTimersByTimeAsync(900);
    });
    expect(result.current.error).toEqual(failure);
    act(() => result.current.clearError());
    await act(async () => {
      await vi.advanceTimersByTimeAsync(600);
    });
    expect(result.current.error).toBeNull();
  });

  it("projects a safe audio-restore warning without blocking the available snapshot", async () => {
    const warning: PlaybackError = {
      code: "preferences-unavailable",
      message: "cannot restore",
    };
    const restored = {
      ...snapshot,
      volume: 0,
      muted: true,
      preferencesError: warning,
    };
    const port = { ...source(), ...playbackReader(async () => ok(restored)) };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => undefined);
    expect(result.current.loading).toBe(false);
    expect(result.current.snapshot?.muted).toBe(true);
    expect(result.current.error).toEqual(warning);
    act(() => result.current.clearError());
    await act(async () => {
      await vi.advanceTimersByTimeAsync(900);
    });
    expect(result.current.error).toBeNull();
    expect(result.current.snapshot?.volume).toBe(0);
  });

  it("clears a previous save failure only after a new action succeeds", async () => {
    const dispatch = vi
      .fn<PlaybackPort["dispatch"]>()
      .mockResolvedValueOnce(err(failure))
      .mockResolvedValue(ok({ ...snapshot, sequence: 2, volume: 35 }));
    const port = { ...source(), dispatch };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => undefined);
    await act(async () => {
      await result.current.dispatch({ type: "set-volume", volume: 30 });
    });
    expect(result.current.error).toEqual(failure);
    await act(async () => {
      await result.current.dispatch({ type: "set-volume", volume: 35 });
    });
    expect(result.current.error).toBeNull();
    expect(result.current.snapshot?.volume).toBe(35);
  });

  it("polls only the known version and preserves queue identity across position samples", async () => {
    const readSnapshot = vi.fn(async () => ok(snapshot));
    const readUpdate = vi.fn<PlaybackPort["readUpdate"]>().mockResolvedValue(
      ok({
        type: "position",
        position: {
          generation: 1,
          sequence: 1,
          mediaId: "one",
          status: "playing",
          positionMs: 2_300,
          durationMs: 60_000,
        },
      }),
    );
    const port = { ...source(), readSnapshot, readUpdate };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => undefined);
    await act(async () => {
      await vi.advanceTimersByTimeAsync(1_500);
    });
    expect(readSnapshot).toHaveBeenCalledOnce();
    expect(readUpdate).toHaveBeenCalledTimes(5);
    expect(readUpdate).toHaveBeenLastCalledWith({ generation: 1, sequence: 1 });
    expect(result.current.snapshot?.queue).toBe(snapshot.queue);
    expect(result.current.snapshot?.sequence).toBe(1);
    expect(result.current.clockSample).toMatchObject({ positionMs: 2_300 });
  });

  it("refreshes a changed queue and uses the new version for the following read", async () => {
    const next = {
      ...snapshot,
      generation: 2,
      sequence: 0,
      positionMs: 0,
      queue: [
        {
          ...snapshot.queue[0],
          id: "two",
          path: "C:/two.flac",
          title: "two",
          kind: "audio" as const,
          durationMs: 60_000,
        },
      ],
    };
    const readUpdate = vi
      .fn<PlaybackPort["readUpdate"]>()
      .mockResolvedValue(ok({ type: "snapshot", snapshot: next }));
    const port = { ...source(), readUpdate };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => {
      await vi.advanceTimersByTimeAsync(600);
    });
    expect(result.current.clockSample?.mediaId).toBe("two");
    expect(result.current.snapshot?.queue).toBe(next.queue);
    expect(readUpdate).toHaveBeenNthCalledWith(1, {
      generation: 1,
      sequence: 1,
    });
    expect(readUpdate).toHaveBeenNthCalledWith(2, {
      generation: 2,
      sequence: 0,
    });
  });

  it.each(["completed", "failed"] as const)(
    "observes native %s status without a frontend command",
    async (status) => {
      const readUpdate = vi.fn<PlaybackPort["readUpdate"]>().mockResolvedValue(
        ok({
          type: "snapshot",
          snapshot: { ...snapshot, sequence: 2, status },
        }),
      );
      const port = { ...source(), readUpdate };
      const { result } = renderHook(() => usePlayback(port));
      await act(async () => {
        await vi.advanceTimersByTimeAsync(300);
      });
      expect(result.current.snapshot?.status).toBe(status);
      expect(result.current.clockSample?.status).toBe(status);
    },
  );

  it("discards a pending narrow read after a command and asks with the command version", async () => {
    const pending = deferred<Result<PlaybackUpdate, PlaybackError>>();
    const readUpdate = vi.fn(() => pending.promise);
    const paused = {
      ...snapshot,
      sequence: 2,
      status: "paused" as const,
      positionMs: 3_000,
    };
    const port = { ...source(), readUpdate, dispatch: async () => ok(paused) };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300);
    });
    await act(async () => {
      await result.current.dispatch({ type: "pause" });
    });
    const sample = result.current.clockSample;
    await act(async () =>
      pending.resolve(
        ok({
          type: "position",
          position: {
            generation: 1,
            sequence: 1,
            mediaId: "one",
            status: "playing",
            positionMs: 2_300,
            durationMs: 60_000,
          },
        }),
      ),
    );
    expect(result.current.snapshot).toBe(paused);
    expect(result.current.clockSample).toBe(sample);
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300);
    });
    expect(readUpdate).toHaveBeenLastCalledWith({ generation: 1, sequence: 2 });
  });

  it("ignores mismatched position payloads and recovers with a full read", async () => {
    const readSnapshot = vi.fn(async () => ok({ ...snapshot }));
    const readUpdate = vi.fn<PlaybackPort["readUpdate"]>().mockResolvedValue(
      ok({
        type: "position",
        position: {
          generation: 1,
          sequence: 1,
          mediaId: "wrong-item",
          status: "playing",
          positionMs: 50_000,
          durationMs: 60_000,
        },
      }),
    );
    const port = { ...source(), readSnapshot, readUpdate };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => undefined);
    const sample = result.current.clockSample;
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300);
    });
    expect(result.current.clockSample).toBe(sample);
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300);
    });
    expect(readSnapshot).toHaveBeenCalledTimes(2);
    expect(result.current.snapshot?.positionMs).toBe(2_000);
  });

  it("recovers from a rejected conditional read without leaking its diagnostic", async () => {
    const readUpdate = vi
      .fn<PlaybackPort["readUpdate"]>()
      .mockRejectedValueOnce(new Error("private diagnostic"))
      .mockResolvedValue(ok({ type: "snapshot", snapshot }));
    const port = { ...source(), readUpdate };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300);
    });
    expect(result.current.error?.code).toBe("transport");
    expect(result.current.error?.message).not.toContain("private diagnostic");
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300);
    });
    expect(result.current.error).toBeNull();
    expect(readUpdate).toHaveBeenCalledTimes(2);
  });

  it("ignores a conditional read that settles after unmount", async () => {
    const pending = deferred<Result<PlaybackUpdate, PlaybackError>>();
    const port = { ...source(), readUpdate: () => pending.promise };
    const { result, unmount } = renderHook(() => usePlayback(port));
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300);
    });
    const sample = result.current.clockSample;
    unmount();
    await act(async () =>
      pending.resolve(
        ok({
          type: "snapshot",
          snapshot: { ...snapshot, generation: 2, positionMs: 0 },
        }),
      ),
    );
    expect(result.current.clockSample).toBe(sample);
  });

  it("timestamps accepted native samples and never overlaps polling reads", async () => {
    const first = deferred<PlaybackResult>();
    const readSnapshot = vi.fn(() => first.promise);
    const port = { ...source(), ...playbackReader(readSnapshot) };
    vi.spyOn(performance, "now").mockReturnValue(123);
    const { result } = renderHook(() => usePlayback(port));
    expect(result.current.loading).toBe(true);
    await act(async () => {
      await vi.advanceTimersByTimeAsync(900);
    });
    expect(readSnapshot).toHaveBeenCalledOnce();
    await act(async () => first.resolve(ok(snapshot)));
    expect(result.current.loading).toBe(false);
    expect(result.current.clockSample).toMatchObject({
      sampledAtMs: 123,
      positionMs: 2_000,
      mediaId: "one",
    });
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300);
    });
    expect(readSnapshot).toHaveBeenCalledTimes(2);
  });

  it("rejects a late pre-command read even at the same generation and sequence", async () => {
    const first = deferred<PlaybackResult>();
    const port = { ...source(), readSnapshot: () => first.promise };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => {
      expect(await result.current.dispatch({ type: "play" })).toBe(true);
    });
    const sample = result.current.clockSample;
    await act(async () => first.resolve(ok({ ...snapshot, positionMs: 100 })));
    expect(result.current.snapshot?.positionMs).toBe(2_000);
    expect(result.current.clockSample).toBe(sample);
  });

  it("does not replace a successful command with an older read error", async () => {
    const first = deferred<PlaybackResult>();
    const port = { ...source(), readSnapshot: () => first.promise };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => {
      await result.current.dispatch({ type: "play" });
    });
    await act(async () => first.resolve(err(failure)));
    expect(result.current.error).toBeNull();
    expect(result.current.snapshot).toBe(snapshot);
  });

  it("keeps busy until all commands settle without letting an older failure win", async () => {
    const first = deferred<PlaybackResult>();
    const second = deferred<PlaybackResult>();
    const dispatch = vi
      .fn<PlaybackPort["dispatch"]>()
      .mockImplementationOnce(() => first.promise)
      .mockImplementationOnce(() => second.promise);
    const readSnapshot = vi.fn(async () => ok(snapshot));
    const port = { ...playbackReader(readSnapshot), dispatch };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => undefined);
    let one: Promise<boolean> | undefined;
    let two: Promise<boolean> | undefined;
    await act(async () => {
      one = result.current.dispatch({ type: "set-volume", volume: 60 });
      two = result.current.dispatch({ type: "set-volume", volume: 80 });
    });
    await act(async () => {
      await vi.advanceTimersByTimeAsync(900);
    });
    expect(readSnapshot).toHaveBeenCalledOnce();
    await act(async () => {
      second.resolve(ok({ ...snapshot, sequence: 3, volume: 80 }));
      await two;
    });
    expect(result.current.busy).toBe(true);
    await act(async () => {
      first.resolve(err(failure));
      await one;
    });
    expect(result.current.busy).toBe(false);
    expect(result.current.snapshot?.volume).toBe(80);
    expect(result.current.error).toBeNull();
  });

  it("does not retimestamp a stale snapshot returned by an older command", async () => {
    const first = deferred<PlaybackResult>();
    const second = deferred<PlaybackResult>();
    const dispatch = vi
      .fn<PlaybackPort["dispatch"]>()
      .mockImplementationOnce(() => first.promise)
      .mockImplementationOnce(() => second.promise);
    const port = { ...source(), dispatch };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => undefined);
    await act(async () => {
      void result.current.dispatch({ type: "seek", positionMs: 10_000 });
      void result.current.dispatch({ type: "seek", positionMs: 20_000 });
    });
    await act(async () =>
      second.resolve(ok({ ...snapshot, sequence: 3, positionMs: 20_000 })),
    );
    const sample = result.current.clockSample;
    await act(async () =>
      first.resolve(ok({ ...snapshot, sequence: 2, positionMs: 10_000 })),
    );
    expect(result.current.snapshot?.positionMs).toBe(20_000);
    expect(result.current.clockSample).toBe(sample);
  });

  it("keeps errors dismissible across polling and resets suppression after recovery", async () => {
    const readSnapshot = vi
      .fn<PlaybackPort["readSnapshot"]>()
      .mockResolvedValue(err(failure));
    const port = { ...source(), ...playbackReader(readSnapshot) };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => undefined);
    expect(result.current.error).toEqual(failure);
    act(() => result.current.clearError());
    await act(async () => {
      await vi.advanceTimersByTimeAsync(600);
    });
    expect(result.current.error).toBeNull();
    readSnapshot.mockResolvedValueOnce(ok(snapshot));
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300);
    });
    await act(async () => {
      await vi.advanceTimersByTimeAsync(300);
    });
    expect(result.current.error).toEqual(failure);
  });

  it("isolates a replaced port and ignores old command and read completions", async () => {
    const oldRead = deferred<PlaybackResult>();
    const oldCommand = deferred<PlaybackResult>();
    const oldPort: PlaybackPort = {
      ...playbackReader(() => oldRead.promise),
      dispatch: () => oldCommand.promise,
    };
    const newSnapshot = {
      ...snapshot,
      generation: 0,
      sequence: 0,
      positionMs: 500,
    };
    const newRead = deferred<PlaybackResult>();
    const newPort: PlaybackPort = {
      ...source(),
      readSnapshot: () => newRead.promise,
    };
    const { result, rerender } = renderHook(({ port }) => usePlayback(port), {
      initialProps: { port: oldPort },
    });
    let pending: Promise<boolean> | undefined;
    await act(async () => {
      pending = result.current.dispatch({ type: "pause" });
    });
    rerender({ port: newPort });
    expect(result.current.snapshot).toBeNull();
    expect(result.current.busy).toBe(false);
    await act(async () => {
      oldRead.resolve(ok(snapshot));
      oldCommand.resolve(ok({ ...snapshot, status: "paused" }));
      expect(await pending).toBe(false);
    });
    expect(result.current.snapshot).toBeNull();
    await act(async () => newRead.resolve(ok(newSnapshot)));
    expect(result.current.snapshot).toBe(newSnapshot);
  });

  it("refreshes on visibility restoration and removes work on unmount", async () => {
    vi.spyOn(document, "hidden", "get").mockReturnValue(false);
    const readSnapshot = vi.fn(async () => ok(snapshot));
    const dispatch = vi.fn(async () => ok(snapshot));
    const port = { ...playbackReader(readSnapshot), dispatch };
    const { result, unmount } = renderHook(() => usePlayback(port));
    await act(async () => undefined);
    await act(async () =>
      document.dispatchEvent(new Event("visibilitychange")),
    );
    expect(readSnapshot).toHaveBeenCalledTimes(2);
    const lateDispatch = result.current.dispatch;
    unmount();
    await act(async () => {
      await vi.advanceTimersByTimeAsync(1_000);
      document.dispatchEvent(new Event("visibilitychange"));
      expect(await lateDispatch({ type: "play" })).toBe(false);
    });
    expect(readSnapshot).toHaveBeenCalledTimes(2);
    expect(dispatch).not.toHaveBeenCalled();
  });

  it("recovers its busy state if an injected port unexpectedly rejects", async () => {
    const port: PlaybackPort = {
      ...source(),
      dispatch: async () => {
        throw new Error("private diagnostic");
      },
    };
    const { result } = renderHook(() => usePlayback(port));
    await act(async () => undefined);
    await act(async () => {
      expect(await result.current.dispatch({ type: "play" })).toBe(false);
    });
    expect(result.current.busy).toBe(false);
    expect(result.current.error?.code).toBe("transport");
    expect(result.current.error?.message).not.toContain("private diagnostic");
  });
});
