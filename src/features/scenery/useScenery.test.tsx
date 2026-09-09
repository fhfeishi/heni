import { act, renderHook } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { err, ok, type Result } from "../../contracts/result";
import {
  emptyScenery,
  type SceneryError,
  type SceneryPort,
  type ScenerySnapshot,
} from "../../contracts/scenery";
import { useScenery } from "./useScenery";

const ready: ScenerySnapshot = {
  state: "ready",
  fileName: "海岸.png",
  dataUrl: "data:image/png;base64,AQID",
};
const port = (): SceneryPort => ({
  read: async () => ok(ready),
  choose: async () => ok(ready),
  clear: async () => ok(emptyScenery),
});
const deferred = <Value,>() => {
  let settle: ((value: Value) => void) | undefined;
  const promise = new Promise<Value>((resolve) => {
    settle = resolve;
  });
  return {
    promise,
    resolve(value: Value) {
      if (settle === undefined)
        throw new Error("Deferred promise was not initialized.");
      settle(value);
    },
  };
};

describe("useScenery", () => {
  it("serializes manual switching and preserves the current image on failed persistence", async () => {
    const pending = deferred<Result<ScenerySnapshot, SceneryError>>();
    const step = vi.fn().mockReturnValue(pending.promise);
    const source: SceneryPort = { ...port(), read: async () => ok({ ...ready, collection: { index: 0, count: 2 } }), step };
    const { result } = renderHook(() => useScenery(source));
    await act(async () => undefined);
    expect(result.current.canStep).toBe(true);
    let completion: Promise<boolean> | undefined;
    act(() => { completion = result.current.next(); });
    await act(async () => { await result.current.previous(); });
    expect(step).toHaveBeenCalledExactlyOnceWith(true);
    await act(async () => { pending.resolve(err("database")); await completion; });
    expect(result.current.imageUrl).toBe(ready.state === "ready" ? ready.dataUrl : null);
    expect(result.current.error).toBe("database");
    expect(result.current.busy).toBe(false);
  });
  it("restores the image and clears only after a successful commit", async () => {
    const { result } = renderHook(() => useScenery(testPort));
    expect(result.current.loading).toBe(true);
    await act(async () => undefined);
    expect(result.current.imageUrl).toBe("data:image/png;base64,AQID");
    await act(async () => {
      await result.current.clear();
    });
    expect(result.current.snapshot).toEqual(emptyScenery);
    expect(result.current.imageUrl).toBeNull();
  });

  it("preserves a committed image on cancellation and failed writes", async () => {
    const source: SceneryPort = {
      ...port(),
      choose: async () => ok(null),
      clear: async () => err("database"),
    };
    const { result } = renderHook(() => useScenery(source));
    await act(async () => undefined);
    await act(async () => {
      await result.current.choose();
    });
    expect(result.current.snapshot).toEqual(ready);
    await act(async () => {
      await result.current.clear();
    });
    expect(result.current.snapshot).toEqual(ready);
    expect(result.current.error).toBe("database");
  });

  it("guards hydration and rapid repeated operations synchronously", async () => {
    const initial = deferred<Result<ScenerySnapshot, SceneryError>>();
    const choice = deferred<Result<ScenerySnapshot | null, SceneryError>>();
    const choose = vi.fn(() => choice.promise);
    const clear = vi.fn(async () => ok(emptyScenery));
    const source: SceneryPort = { read: () => initial.promise, choose, clear };
    const { result } = renderHook(() => useScenery(source));
    await act(async () => {
      expect(await result.current.choose()).toBe(false);
    });
    expect(choose).not.toHaveBeenCalled();
    await act(async () => {
      initial.resolve(ok(ready));
    });
    let pending: Promise<boolean> | undefined;
    await act(async () => {
      pending = result.current.choose();
      expect(await result.current.choose()).toBe(false);
      expect(await result.current.clear()).toBe(false);
    });
    expect(choose).toHaveBeenCalledTimes(1);
    expect(clear).not.toHaveBeenCalled();
    expect(result.current.busy).toBe(true);
    await act(async () => {
      choice.resolve(ok(null));
      await pending;
    });
    expect(result.current.busy).toBe(false);
    expect(result.current.snapshot).toEqual(ready);
  });

  it("ignores an old read after the port changes", async () => {
    const initial = deferred<Result<ScenerySnapshot, SceneryError>>();
    const oldPort: SceneryPort = { ...port(), read: () => initial.promise };
    const nextPort: SceneryPort = {
      ...port(),
      read: async () => ok(emptyScenery),
    };
    const { result, rerender } = renderHook(
      ({ source }) => useScenery(source),
      { initialProps: { source: oldPort } },
    );
    rerender({ source: nextPort });
    await act(async () => undefined);
    await act(async () => {
      initial.resolve(ok(ready));
    });
    expect(result.current.snapshot).toEqual(emptyScenery);
  });

  it("ignores an old mutation after the port changes", async () => {
    const choice = deferred<Result<ScenerySnapshot | null, SceneryError>>();
    const oldPort: SceneryPort = { ...port(), choose: () => choice.promise };
    const nextPort: SceneryPort = {
      ...port(),
      read: async () => ok(emptyScenery),
    };
    const { result, rerender } = renderHook(
      ({ source }) => useScenery(source),
      { initialProps: { source: oldPort } },
    );
    await act(async () => undefined);
    let pending: Promise<boolean> | undefined;
    act(() => {
      pending = result.current.choose();
    });
    rerender({ source: nextPort });
    await act(async () => undefined);
    await act(async () => {
      choice.resolve(ok(ready));
      await pending;
    });
    expect(result.current.snapshot).toEqual(emptyScenery);
    expect(result.current.busy).toBe(false);
  });

  it("shows a local read failure and permits recovery", async () => {
    const source: SceneryPort = {
      ...port(),
      read: async () => err("transport"),
    };
    const { result } = renderHook(() => useScenery(source));
    await act(async () => undefined);
    expect(result.current.error).toBe("transport");
    await act(async () => {
      await result.current.choose();
    });
    expect(result.current.error).toBeNull();
    expect(result.current.snapshot).toEqual(ready);
  });

  it("uses a fallback only when the currently displayed image fails", async () => {
    const { result } = renderHook(() => useScenery(testPort));
    await act(async () => undefined);
    act(() => {
      result.current.reportImageFailure("data:image/png;base64,OLD");
    });
    expect(result.current.snapshot).toEqual(ready);
    act(() => {
      result.current.reportImageFailure("data:image/png;base64,AQID");
    });
    expect(result.current.snapshot).toEqual({
      state: "unavailable",
      fileName: "海岸.png",
      reason: "unsupported-image",
    });
    expect(result.current.imageUrl).toBeNull();
  });
});

const testPort = port();
