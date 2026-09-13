import { act, fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type { PlaybackSnapshot } from "../../contracts/playback";
import { MiniPlayer } from "./MiniPlayer";

const item = {
  id: "c:\\music\\one.flac",
  path: "C:\\Music\\one.flac",
  title: "one.flac",
  kind: "audio" as const,
  durationMs: 60_000,
};

const snapshot: PlaybackSnapshot = {
  generation: 3,
  sequence: 8,
  status: "playing",
  queue: [item],
  currentIndex: 0,
  positionMs: 12_000,
  durationMs: 60_000,
  volume: 70,
  muted: false,
  repeatMode: "all",
  shuffle: false,
};

describe("MiniPlayer", () => {
  it("controls the existing playback snapshot without creating another session", () => {
    const dispatch = vi.fn();
    const openQueue = vi.fn();
    render(
      <MiniPlayer
        snapshot={snapshot}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
        onOpenQueue={openQueue}
      />,
    );

    expect(screen.getByText("one.flac")).toBeInTheDocument();
    expect(screen.getByText("正在聆听")).toBeInTheDocument();
    expect(screen.queryByText(item.path)).not.toBeInTheDocument();
    expect(screen.queryByText(/^H$/u)).toBeNull();
    const queue = screen.getByRole("button", { name: "队列 1" });
    expect(queue.textContent).toBe("");
    expect(queue.querySelector("svg")).toHaveAttribute("aria-hidden", "true");
    const mute = screen.getByRole("button", { name: "静音" });
    expect(mute).toHaveAttribute("title", "静音");
    expect(mute.querySelector("svg")).toBeInTheDocument();
    fireEvent.click(mute);
    expect(dispatch).toHaveBeenCalledWith({ type: "set-muted", muted: true });
    fireEvent.click(screen.getByRole("button", { name: "暂停" }));
    fireEvent.click(screen.getByRole("button", { name: "队列 1" }));

    expect(dispatch).toHaveBeenCalledWith({ type: "pause" });
    expect(openQueue).toHaveBeenCalledOnce();
  });

  it("reuses the generation-safe seek interaction", async () => {
    const dispatch = vi.fn(async () => true);
    render(
      <MiniPlayer
        snapshot={snapshot}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
        onOpenQueue={vi.fn()}
      />,
    );

    const progress = screen.getByRole("slider", { name: "播放进度" });
    fireEvent.change(progress, { target: { value: "30000" } });
    await act(async () => {
      fireEvent.pointerUp(progress);
    });

    expect(dispatch).toHaveBeenCalledWith({
      type: "seek",
      positionMs: 30_000,
    });
  });
});
