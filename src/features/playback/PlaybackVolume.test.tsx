import { act, fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import type { PlaybackSnapshot } from "../../contracts/playback";
import { PlaybackVolume } from "./PlaybackVolume";

const snapshot: PlaybackSnapshot = {
  generation: 0,
  sequence: 0,
  status: "idle",
  queue: [],
  currentIndex: null,
  positionMs: 0,
  durationMs: null,
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
        throw new Error("Uninitialized deferred result");
      settle(value);
    },
  };
};

describe("PlaybackVolume", () => {
  it("maps the rail to stored volume and mutes without erasing the level", () => {
    const { container, rerender } = render(<PlaybackVolume snapshot={snapshot} busy={false} onDispatch={vi.fn()} />);
    expect(container.firstChild).toHaveStyle({ "--volume-position": "70%" });
    rerender(<PlaybackVolume snapshot={{ ...snapshot, muted: true }} busy={false} onDispatch={vi.fn()} />);
    expect(container.firstChild).toHaveAttribute("data-muted", "true");
    expect(screen.getByRole("slider", { name: "音量" })).toHaveValue("70");
    expect(screen.getByRole("button", { name: "恢复声音" })).toHaveAttribute("aria-pressed", "true");
  });
  it("previews a drag and commits only the final target, even in an empty queue", async () => {
    const dispatch = vi.fn(async () => true);
    render(
      <PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />,
    );
    const slider = screen.getByRole("slider", { name: "音量" });
    fireEvent.change(slider, { target: { value: "30" } });
    fireEvent.change(slider, { target: { value: "42" } });
    expect(slider).toHaveValue("42");
    expect(slider).toHaveAttribute("aria-valuetext", "42%");
    expect(dispatch).not.toHaveBeenCalled();
    await act(async () => fireEvent.pointerUp(slider));
    expect(dispatch).toHaveBeenCalledExactlyOnceWith({
      type: "set-volume",
      volume: 42,
    });
  });

  it("keeps focus and target while saving, then returns to authority after failure", async () => {
    const pending = deferred();
    const dispatch = vi.fn(() => pending.promise);
    const { rerender } = render(
      <PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />,
    );
    const slider = screen.getByRole("slider", { name: "音量" });
    slider.focus();
    fireEvent.change(slider, { target: { value: "42" } });
    fireEvent.pointerUp(slider);
    rerender(
      <PlaybackVolume snapshot={snapshot} busy={true} onDispatch={dispatch} />,
    );
    expect(slider).toHaveFocus();
    expect(slider).toHaveValue("42");
    expect(slider).toBeEnabled();
    expect(slider).toHaveAttribute("aria-busy", "true");
    fireEvent.pointerUp(slider);
    fireEvent.change(slider, { target: { value: "60" } });
    expect(dispatch).toHaveBeenCalledOnce();
    expect(slider).toHaveValue("42");
    rerender(
      <PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />,
    );
    await act(async () => pending.resolve(false));
    expect(slider).toHaveValue("70");
    expect(slider).toHaveFocus();
    expect(slider).not.toHaveAttribute("aria-busy");
  });

  it.each(["pointer-cancel", "capture-lost", "blur", "escape"])(
    "cancels an uncommitted volume draft on %s",
    (reason) => {
      const dispatch = vi.fn(async () => true);
      render(
        <PlaybackVolume
          snapshot={snapshot}
          busy={false}
          onDispatch={dispatch}
        />,
      );
      const slider = screen.getByRole("slider", { name: "音量" });
      fireEvent.change(slider, { target: { value: "20" } });
      if (reason === "pointer-cancel") fireEvent.pointerCancel(slider);
      else if (reason === "capture-lost") fireEvent.lostPointerCapture(slider);
      else if (reason === "blur") fireEvent.blur(slider);
      else fireEvent.keyDown(slider, { key: "Escape" });
      fireEvent.pointerUp(slider);
      expect(slider).toHaveValue("70");
      expect(dispatch).not.toHaveBeenCalled();
    },
  );

  it.each([
    ["ArrowLeft", 69],
    ["ArrowUp", 71],
    ["PageDown", 60],
    ["Home", 0],
    ["End", 100],
  ])("commits keyboard %s as a bounded volume of %s", async (key, expected) => {
    const dispatch = vi.fn(async () => true);
    render(
      <PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />,
    );
    const slider = screen.getByRole("slider", { name: "音量" });
    fireEvent.keyDown(slider, { key });
    expect(dispatch).not.toHaveBeenCalled();
    await act(async () => fireEvent.keyUp(slider, { key }));
    expect(dispatch).toHaveBeenCalledExactlyOnceWith({
      type: "set-volume",
      volume: expected,
    });
  });

  it("preserves a draft across time/track updates but discards an external volume change", () => {
    const dispatch = vi.fn(async () => true);
    const { rerender } = render(
      <PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />,
    );
    const slider = screen.getByRole("slider", { name: "音量" });
    fireEvent.change(slider, { target: { value: "20" } });
    rerender(
      <PlaybackVolume
        snapshot={{ ...snapshot, generation: 1, sequence: 2, positionMs: 300 }}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    expect(slider).toHaveValue("20");
    rerender(
      <PlaybackVolume
        snapshot={{ ...snapshot, volume: 50 }}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    expect(slider).toHaveValue("50");
  });

  it("keeps mute independent of the presence of a current media item", async () => {
    const dispatch = vi.fn(async () => true);
    render(
      <PlaybackVolume
        snapshot={{ ...snapshot, muted: true }}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    await act(async () =>
      fireEvent.click(screen.getByRole("button", { name: "恢复声音" })),
    );
    expect(dispatch).toHaveBeenCalledExactlyOnceWith({
      type: "set-muted",
      muted: false,
    });
  });

  it("does not revive a cancelled draft when external audio values return to their origin", () => {
    const dispatch = vi.fn(async () => true);
    const { rerender } = render(
      <PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />,
    );
    const slider = screen.getByRole("slider", { name: "音量" });
    fireEvent.change(slider, { target: { value: "20" } });
    rerender(
      <PlaybackVolume
        snapshot={{ ...snapshot, muted: true }}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    expect(slider).toHaveValue("70");
    rerender(
      <PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />,
    );
    fireEvent.pointerUp(slider);
    expect(slider).toHaveValue("70");
    expect(dispatch).not.toHaveBeenCalled();
  });

  it("commits repeated keyboard movement once and keeps focus for the next adjustment", async () => {
    const dispatch = vi.fn(async () => true);
    const { rerender } = render(
      <PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />,
    );
    const slider = screen.getByRole("slider", { name: "音量" });
    slider.focus();
    for (let press = 0; press < 4; press += 1) {
      fireEvent.keyDown(slider, { key: "ArrowLeft", repeat: press > 0 });
    }
    expect(slider).toHaveValue("66");
    expect(dispatch).not.toHaveBeenCalled();
    await act(async () => fireEvent.keyUp(slider, { key: "ArrowLeft" }));
    expect(dispatch).toHaveBeenCalledExactlyOnceWith({
      type: "set-volume",
      volume: 66,
    });
    rerender(
      <PlaybackVolume
        snapshot={{ ...snapshot, volume: 66 }}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    expect(slider).toHaveFocus();
    fireEvent.keyDown(slider, { key: "ArrowLeft" });
    await act(async () => fireEvent.keyUp(slider, { key: "ArrowLeft" }));
    expect(dispatch).toHaveBeenLastCalledWith({
      type: "set-volume",
      volume: 65,
    });
    expect(dispatch).toHaveBeenCalledTimes(2);
  });

  it("abandons an uncommitted gesture on unmount without writing preferences", () => {
    const dispatch = vi.fn(async () => true);
    const { unmount } = render(
      <PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />,
    );
    fireEvent.change(screen.getByRole("slider", { name: "音量" }), {
      target: { value: "20" },
    });
    unmount();
    expect(dispatch).not.toHaveBeenCalled();
  });

  it("disables only unavailable or externally occupied controls", () => {
    const dispatch = vi.fn(async () => true);
    const { rerender } = render(
      <PlaybackVolume snapshot={null} busy={false} onDispatch={dispatch} />,
    );
    expect(screen.getByRole("slider", { name: "音量" })).toBeDisabled();
    rerender(
      <PlaybackVolume snapshot={snapshot} busy={true} onDispatch={dispatch} />,
    );
    expect(screen.getByRole("slider", { name: "音量" })).toBeDisabled();
  });

  it("allows a submitted save to finish after unmount without updating the old control", async () => {
    const pending = deferred();
    const dispatch = vi.fn(() => pending.promise);
    const { unmount } = render(
      <PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />,
    );
    const slider = screen.getByRole("slider", { name: "音量" });
    fireEvent.change(slider, { target: { value: "35" } });
    fireEvent.pointerUp(slider);
    unmount();
    await act(async () => pending.resolve(true));
    expect(dispatch).toHaveBeenCalledOnce();
  });
});
