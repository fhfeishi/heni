import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type { PlaybackSnapshot } from "../../contracts/playback";
import { PlaybackBar } from "./PlaybackBar";

const item = {
  id: "c:\\music\\one.flac",
  path: "C:\\Music\\one.flac",
  title: "一首标题很长但不能挤压播放进度的本地音乐.flac",
  kind: "audio" as const,
  durationMs: null,
};

const snapshot = (
  overrides: Partial<PlaybackSnapshot> = {},
): PlaybackSnapshot => ({
  generation: 1,
  sequence: 1,
  status: "completed",
  queue: [item],
  currentIndex: 0,
  positionMs: 0,
  durationMs: null,
  volume: 72,
  muted: false,
  repeatMode: "all",
  shuffle: false,
  ...overrides,
});

describe("PlaybackBar", () => {
  it("renders unknown duration without disabling replay after completion", () => {
    const dispatch = vi.fn();

    render(
      <PlaybackBar
        snapshot={snapshot()}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
        onOpenQueue={vi.fn()}
      />,
    );

    expect(screen.getByText(item.title)).toBeInTheDocument();
    expect(screen.getByText("--:--")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "播放" }));
    expect(dispatch).toHaveBeenCalledWith({ type: "play" });
  });

  it("drops an unfinished seek draft when the playback generation changes", () => {
    const dispatch = vi.fn();
    const { rerender } = render(
      <PlaybackBar
        snapshot={snapshot({ durationMs: 60_000 })}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
        onOpenQueue={vi.fn()}
      />,
    );
    const progress = screen.getByRole("slider", { name: "播放进度" });

    fireEvent.change(progress, { target: { value: "30000" } });
    expect(progress).toHaveValue("30000");

    rerender(
      <PlaybackBar
        clockSample={null}
        snapshot={snapshot({
          generation: 2,
          sequence: 0,
          positionMs: 5_000,
          durationMs: 60_000,
        })}
        currentItem={{ ...item, id: "c:\\music\\two.flac" }}
        busy={false}
        onDispatch={dispatch}
        onOpenQueue={vi.fn()}
      />,
    );

    expect(progress).toHaveValue("5000");
  });

  it("exposes pause as the primary action while audio is playing", () => {
    const dispatch = vi.fn();

    render(
      <PlaybackBar
        snapshot={snapshot({ status: "playing", durationMs: 60_000 })}
        clockSample={null}
        currentItem={item}
        busy={false}
        onDispatch={dispatch}
        onOpenQueue={vi.fn()}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "暂停" }));
    expect(dispatch).toHaveBeenCalledWith({ type: "pause" });
  });
});
