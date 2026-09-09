import { act, fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type { PlaybackSnapshot } from "../../contracts/playback";
import { PlaybackProgress } from "./PlaybackProgress";
import { projectPlaybackPosition } from "./application/projectPlaybackPosition";
import { createPlaybackClockSample } from "./application/playbackClock";

const item = {
  id: "one",
  path: "C:/one.flac",
  title: "one",
  kind: "audio" as const,
  durationMs: 60_000,
};
const snapshot: PlaybackSnapshot = {
  generation: 1,
  sequence: 1,
  status: "playing",
  currentIndex: 0,
  queue: [item],
  positionMs: 2_000,
  durationMs: 60_000,
  volume: 70,
  muted: false,
  repeatMode: "all",
  shuffle: false,
};
const deferred = () => {
  let settle: ((value: boolean) => void) | undefined;
  const promise = new Promise<boolean>((resolve) => {
    settle = resolve;
  });
  return {
    promise,
    resolve(value: boolean) {
      if (settle === undefined)
        throw new Error("Deferred result was not initialized.");
      settle(value);
    },
  };
};

describe("PlaybackProgress", () => {
  it("keeps an uncommitted seek while ordinary position samples arrive", async () => {
    const dispatch = vi.fn(async () => true);
    const { rerender } = render(
      <PlaybackProgress
        snapshot={snapshot}
        clockSample={createPlaybackClockSample(snapshot, performance.now())}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    const slider = screen.getByRole("slider", { name: "播放进度" });
    fireEvent.change(slider, { target: { value: "30000" } });
    const updated = projectPlaybackPosition(snapshot, {
      generation: 1,
      sequence: 1,
      status: "playing",
      mediaId: "one",
      positionMs: 2_300,
      durationMs: 60_000,
    });
    if (updated === null) throw new Error("Expected a loaded snapshot.");
    rerender(
      <PlaybackProgress
        snapshot={updated}
        clockSample={createPlaybackClockSample(updated, performance.now())}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    expect(slider).toHaveValue("30000");
    await act(async () => fireEvent.pointerUp(slider));
    expect(dispatch).toHaveBeenCalledExactlyOnceWith({
      type: "seek",
      positionMs: 30_000,
    });
  });

  it("retains the proposed position until a seek resolves and dispatches only once", async () => {
    const pending = deferred();
    const dispatch = vi.fn(() => pending.promise);
    const { rerender } = render(
      <PlaybackProgress
        snapshot={snapshot}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    const slider = screen.getByRole("slider", { name: "播放进度" });
    slider.focus();
    fireEvent.change(slider, { target: { value: "30000" } });
    fireEvent.pointerUp(slider);
    rerender(
      <PlaybackProgress
        snapshot={snapshot}
        clockSample={null}
        currentItem={item}
        busy={true}
        onDispatch={dispatch}
      />,
    );
    fireEvent.pointerUp(slider);
    fireEvent.lostPointerCapture(slider);
    fireEvent.keyDown(slider, { key: "ArrowRight" });
    fireEvent.keyUp(slider, { key: "ArrowRight" });
    expect(slider).toHaveValue("30000");
    expect(slider).toBeEnabled();
    expect(slider).toHaveFocus();
    expect(slider).toHaveAttribute("aria-disabled", "true");
    expect(dispatch).toHaveBeenCalledExactlyOnceWith({
      type: "seek",
      positionMs: 30_000,
    });
    rerender(
      <PlaybackProgress
        snapshot={{ ...snapshot, sequence: 2, positionMs: 30_050 }}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    await act(async () => pending.resolve(true));
    expect(slider).toHaveValue("30050");
    expect(slider).toBeEnabled();
    expect(slider).toHaveFocus();
    expect(slider).not.toHaveAttribute("aria-disabled");
  });

  it("returns to the authoritative position after a failed seek", async () => {
    const pending = deferred();
    render(
      <PlaybackProgress
        snapshot={snapshot}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={() => pending.promise}
      />,
    );
    const slider = screen.getByRole("slider", { name: "播放进度" });
    fireEvent.change(slider, { target: { value: "30000" } });
    fireEvent.pointerUp(slider);
    expect(slider).toHaveValue("30000");
    await act(async () => pending.resolve(false));
    expect(slider).toHaveValue("2000");
  });

  it.each(["pointer-cancel", "blur", "escape", "lost-capture"])(
    "cancels an uncommitted draft on %s",
    (reason) => {
      const dispatch = vi.fn(async () => true);
      render(
        <PlaybackProgress
          snapshot={snapshot}
          clockSample={null}
          currentItem={item}
          busy={false}
          onDispatch={dispatch}
        />,
      );
      const slider = screen.getByRole("slider", { name: "播放进度" });
      fireEvent.change(slider, { target: { value: "30000" } });
      if (reason === "pointer-cancel") fireEvent.pointerCancel(slider);
      else if (reason === "blur") fireEvent.blur(slider);
      else if (reason === "lost-capture") fireEvent.lostPointerCapture(slider);
      else fireEvent.keyDown(slider, { key: "Escape" });
      fireEvent.pointerUp(slider);
      expect(slider).toHaveValue("2000");
      expect(dispatch).not.toHaveBeenCalled();
    },
  );

  it("keeps keyboard seeking in seconds and provides a readable accessible value", async () => {
    const dispatch = vi.fn(async () => false);
    render(
      <PlaybackProgress
        snapshot={snapshot}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    const slider = screen.getByRole("slider", { name: "播放进度" });
    expect(slider).toHaveAttribute("step", "1");
    fireEvent.keyDown(slider, { key: "ArrowRight" });
    expect(slider).toHaveValue("3000");
    expect(slider).toHaveAttribute("aria-valuetext", "0:03 / 1:00");
    fireEvent.keyUp(slider, { key: "Shift" });
    expect(dispatch).not.toHaveBeenCalled();
    await act(async () => {
      fireEvent.keyUp(slider, { key: "ArrowRight" });
    });
    expect(dispatch).toHaveBeenLastCalledWith({
      type: "seek",
      positionMs: 3_000,
    });
    fireEvent.keyDown(slider, { key: "PageUp" });
    expect(slider).toHaveValue("12000");
    fireEvent.keyDown(slider, { key: "End" });
    expect(slider).toHaveValue("60000");
    fireEvent.keyDown(slider, { key: "ArrowRight" });
    expect(slider).toHaveValue("60000");
    fireEvent.keyDown(slider, { key: "Home" });
    fireEvent.keyDown(slider, { key: "ArrowLeft" });
    expect(slider).toHaveValue("0");
  });

  it("drops old gestures after a generation change or an intervening native command", () => {
    const dispatch = vi.fn(async () => true);
    const { rerender } = render(
      <PlaybackProgress
        snapshot={snapshot}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    const slider = screen.getByRole("slider", { name: "播放进度" });
    fireEvent.change(slider, { target: { value: "30000" } });
    rerender(
      <PlaybackProgress
        snapshot={{ ...snapshot, generation: 2, positionMs: 500 }}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    fireEvent.pointerUp(slider);
    expect(slider).toHaveValue("500");
    expect(dispatch).not.toHaveBeenCalled();
    fireEvent.change(slider, { target: { value: "30000" } });
    rerender(
      <PlaybackProgress
        snapshot={{
          ...snapshot,
          generation: 2,
          sequence: 2,
          status: "paused",
          positionMs: 600,
        }}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    fireEvent.pointerUp(slider);
    expect(slider).toHaveValue("600");
    expect(dispatch).not.toHaveBeenCalled();
  });

  it("uses pointer capture so releasing outside the slider still reaches the control", () => {
    render(
      <PlaybackProgress
        snapshot={snapshot}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={vi.fn(async () => true)}
      />,
    );
    const slider = screen.getByRole("slider", { name: "播放进度" });
    const setPointerCapture = vi.fn();
    Object.defineProperty(slider, "setPointerCapture", {
      value: setPointerCapture,
    });
    fireEvent.pointerDown(slider);
    expect(setPointerCapture).toHaveBeenCalledOnce();
  });

  it("does not leave a draft or dispatch after unmount while waiting for native seek", async () => {
    const pending = deferred();
    const dispatch = vi.fn(() => pending.promise);
    const { unmount } = render(
      <PlaybackProgress
        snapshot={snapshot}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    const slider = screen.getByRole("slider", { name: "播放进度" });
    fireEvent.change(slider, { target: { value: "30000" } });
    fireEvent.pointerUp(slider);
    unmount();
    await act(async () => pending.resolve(true));
    expect(dispatch).toHaveBeenCalledOnce();
  });
});
