import { act, renderHook } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { SCENERY_ROTATION_MS, useSceneryRotation } from "./useSceneryRotation";

describe("scenery rotation", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.spyOn(document, "hasFocus").mockReturnValue(true);
    vi.spyOn(document, "hidden", "get").mockReturnValue(false);
  });
  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });
  const tick = async (ms = SCENERY_ROTATION_MS) => {
    await act(async () => { await vi.advanceTimersByTimeAsync(ms); });
  };

  it("waits a full interval, never overlaps pending work, and stops on failure", async () => {
    let resolve: ((success: boolean) => void) | undefined;
    const next = vi.fn(() => new Promise<boolean>((done) => { resolve = done; }));
    const { unmount } = renderHook(() => useSceneryRotation(true, next));
    await tick(SCENERY_ROTATION_MS - 1);
    expect(next).not.toHaveBeenCalled();
    await tick(1);
    await tick(SCENERY_ROTATION_MS * 3);
    expect(next).toHaveBeenCalledOnce();
    await act(async () => { resolve?.(false); });
    await tick();
    expect(next).toHaveBeenCalledOnce();
    unmount();
    expect(vi.getTimerCount()).toBe(0);
  });

  it("pauses while hidden or blurred and does not catch up after returning", async () => {
    const next = vi.fn().mockResolvedValue(true);
    const { unmount } = renderHook(() => useSceneryRotation(true, next));
    act(() => window.dispatchEvent(new Event("blur")));
    await tick(SCENERY_ROTATION_MS * 5);
    expect(next).not.toHaveBeenCalled();
    act(() => window.dispatchEvent(new Event("focus")));
    await tick(SCENERY_ROTATION_MS - 1);
    expect(next).not.toHaveBeenCalled();
    await tick(1);
    expect(next).toHaveBeenCalledOnce();
    vi.spyOn(document, "hidden", "get").mockReturnValue(true);
    act(() => document.dispatchEvent(new Event("visibilitychange")));
    await tick();
    expect(next).toHaveBeenCalledOnce();
    unmount();
    expect(vi.getTimerCount()).toBe(0);
  });

  it("responds to reduced motion changes and cleans up when disabled", async () => {
    const events = new EventTarget();
    let reduced = true;
    vi.stubGlobal("matchMedia", () => ({
      get matches() { return reduced; },
      addEventListener: events.addEventListener.bind(events),
      removeEventListener: events.removeEventListener.bind(events),
    }));
    const next = vi.fn().mockResolvedValue(true);
    const { rerender, unmount } = renderHook(({ enabled }) => useSceneryRotation(enabled, next), { initialProps: { enabled: true } });
    await tick();
    expect(next).not.toHaveBeenCalled();
    act(() => { reduced = false; events.dispatchEvent(new Event("change")); });
    await tick();
    expect(next).toHaveBeenCalledOnce();
    rerender({ enabled: false });
    await tick();
    expect(next).toHaveBeenCalledOnce();
    unmount();
    expect(vi.getTimerCount()).toBe(0);
  });

  it("does not reschedule a late successful operation after unmount", async () => {
    let resolve: ((success: boolean) => void) | undefined;
    const next = vi.fn(() => new Promise<boolean>((done) => { resolve = done; }));
    const { unmount } = renderHook(() => useSceneryRotation(true, next));
    await tick();
    unmount();
    await act(async () => { resolve?.(true); });
    expect(vi.getTimerCount()).toBe(0);
  });
});
