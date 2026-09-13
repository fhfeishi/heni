import { act, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { PlaybackCommand, PlaybackSnapshot } from "../../contracts/playback";
import { PlaybackVolume } from "./PlaybackVolume";

const snapshot: PlaybackSnapshot = {
  generation: 0, sequence: 0, status: "idle", queue: [], currentIndex: null,
  positionMs: 0, durationMs: null, volume: 70, muted: false, repeatMode: "all", shuffle: false,
};
const types = (dispatch: ReturnType<typeof vi.fn<(command: PlaybackCommand) => Promise<boolean>>>) =>
  dispatch.mock.calls.map(([command]) => command.type);
afterEach(() => vi.useRealTimers());

describe("PlaybackVolume", () => {
  it("auditions during dragging and persists the final target once", async () => {
    vi.useFakeTimers();
    const dispatch = vi.fn<(command: PlaybackCommand) => Promise<boolean>>().mockResolvedValue(true);
    render(<PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />);
    const slider = screen.getByRole("slider", { name: "音量" });
    fireEvent.change(slider, { target: { value: "30" } });
    await act(async () => { await vi.advanceTimersByTimeAsync(40); });
    expect(types(dispatch)).toEqual(["preview-volume"]);
    fireEvent.change(slider, { target: { value: "42" } });
    await act(async () => fireEvent.pointerUp(slider));
    expect(types(dispatch)).toEqual(["preview-volume", "preview-volume", "commit-volume-preview"]);
    expect(dispatch.mock.calls.at(-1)?.[0]).toMatchObject({ type: "commit-volume-preview", volume: 42 });
  });

  it("keeps focus while saving, ignores duplicate submission, and restores authority on failure", async () => {
    let settle: (value: boolean) => void = () => { throw new Error("Uninitialized"); };
    const pending = new Promise<boolean>((resolve) => { settle = resolve; });
    const dispatch = vi.fn(async (command: PlaybackCommand) => command.type === "commit-volume-preview" ? pending : true);
    const { rerender } = render(<PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />);
    const slider = screen.getByRole("slider", { name: "音量" });
    slider.focus();
    fireEvent.change(slider, { target: { value: "42" } });
    await act(async () => fireEvent.pointerUp(slider));
    rerender(<PlaybackVolume snapshot={snapshot} busy onDispatch={dispatch} />);
    expect(slider).toHaveFocus();
    expect(slider).toHaveValue("42");
    expect(slider).toBeEnabled();
    expect(slider).toHaveAttribute("aria-busy", "true");
    fireEvent.pointerUp(slider);
    fireEvent.change(slider, { target: { value: "60" } });
    expect(types(dispatch)).toEqual(["preview-volume", "commit-volume-preview"]);
    await act(async () => settle(false));
    expect(slider).toHaveValue("70");
    expect(screen.getByRole("status")).toHaveTextContent("音量调整未完成");
    expect(types(dispatch)).toEqual(["preview-volume", "commit-volume-preview", "cancel-volume-preview"]);
  });

  it.each(["pointer-cancel", "capture-lost", "blur", "escape", "window-blur"])("cancels an audible preview on %s", async (reason) => {
    vi.useFakeTimers();
    const dispatch = vi.fn<(command: PlaybackCommand) => Promise<boolean>>().mockResolvedValue(true);
    render(<PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />);
    const slider = screen.getByRole("slider", { name: "音量" });
    fireEvent.change(slider, { target: { value: "20" } });
    await act(async () => { await vi.advanceTimersByTimeAsync(40); });
    await act(async () => {
      if (reason === "pointer-cancel") fireEvent.pointerCancel(slider);
      else if (reason === "capture-lost") fireEvent.lostPointerCapture(slider);
      else if (reason === "blur") fireEvent.blur(slider);
      else if (reason === "window-blur") fireEvent(window, new Event("blur"));
      else fireEvent.keyDown(slider, { key: "Escape" });
    });
    fireEvent.pointerUp(slider);
    expect(slider).toHaveValue("70");
    expect(types(dispatch)).toEqual(["preview-volume", "cancel-volume-preview"]);
  });

  it.each([["ArrowLeft", 69], ["ArrowUp", 71], ["PageDown", 60], ["Home", 0], ["End", 100]])(
    "commits keyboard %s at %s", async (key, expected) => {
      const dispatch = vi.fn<(command: PlaybackCommand) => Promise<boolean>>().mockResolvedValue(true);
      render(<PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />);
      const slider = screen.getByRole("slider", { name: "音量" });
      slider.focus();
      fireEvent.keyDown(slider, { key });
      await act(async () => fireEvent.keyUp(slider, { key }));
      expect(dispatch.mock.calls.at(-1)?.[0]).toMatchObject({ type: "commit-volume-preview", volume: expected });
      expect(slider).toHaveFocus();
    },
  );

  it("keeps drafts across position samples but cancels on a track/version change", async () => {
    const dispatch = vi.fn<(command: PlaybackCommand) => Promise<boolean>>().mockResolvedValue(true);
    const { rerender } = render(<PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />);
    const slider = screen.getByRole("slider", { name: "音量" });
    fireEvent.change(slider, { target: { value: "20" } });
    rerender(<PlaybackVolume snapshot={{ ...snapshot, positionMs: 300 }} busy={false} onDispatch={dispatch} />);
    expect(slider).toHaveValue("20");
    await act(async () => rerender(<PlaybackVolume snapshot={{ ...snapshot, generation: 1, sequence: 1 }} busy={false} onDispatch={dispatch} />));
    expect(slider).toHaveValue("70");
    fireEvent.pointerUp(slider);
    expect(types(dispatch)).toEqual(["cancel-volume-preview"]);
  });

  it("can change mute without a current track and shows saved level while muted", async () => {
    const dispatch = vi.fn<(command: PlaybackCommand) => Promise<boolean>>().mockResolvedValue(true);
    const { container } = render(<PlaybackVolume snapshot={{ ...snapshot, muted: true }} busy={false} onDispatch={dispatch} />);
    expect(container.firstChild).toHaveStyle({ "--volume-position": "70%" });
    expect(screen.getByRole("slider", { name: "音量" })).toHaveValue("70");
    await act(async () => fireEvent.click(screen.getByRole("button", { name: "恢复声音" })));
    expect(dispatch).toHaveBeenCalledExactlyOnceWith({ type: "set-muted", muted: false });
  });

  it("cancels an unmounted preview without committing", async () => {
    vi.useFakeTimers();
    const dispatch = vi.fn<(command: PlaybackCommand) => Promise<boolean>>().mockResolvedValue(true);
    const { unmount } = render(<PlaybackVolume snapshot={snapshot} busy={false} onDispatch={dispatch} />);
    fireEvent.change(screen.getByRole("slider", { name: "音量" }), { target: { value: "20" } });
    await act(async () => { await vi.advanceTimersByTimeAsync(40); });
    await act(async () => unmount());
    await act(async () => { await vi.advanceTimersByTimeAsync(3000); });
    expect(types(dispatch)).toEqual(["preview-volume", "cancel-volume-preview"]);
  });

  it("disables only unavailable or externally occupied controls", () => {
    const dispatch = vi.fn(async () => true);
    const { rerender } = render(<PlaybackVolume snapshot={null} busy={false} onDispatch={dispatch} />);
    expect(screen.getByRole("slider", { name: "音量" })).toBeDisabled();
    rerender(<PlaybackVolume snapshot={snapshot} busy onDispatch={dispatch} />);
    expect(screen.getByRole("slider", { name: "音量" })).toBeDisabled();
  });
});
