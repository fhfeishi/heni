import { act, fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import type { PlaybackSnapshot } from "../../contracts/playback";
import { PlaybackModeControl } from "./PlaybackModeControl";

const snapshot: PlaybackSnapshot = { generation: 0, sequence: 0, status: "idle", queue: [], currentIndex: null,
  positionMs: 0, durationMs: null, volume: 70, muted: false, repeatMode: "all", shuffle: false };

describe("PlaybackModeControl", () => {
  it.each([
    ["随机播放", { type: "set-shuffle", shuffle: true }],
    ["单曲循环", { type: "set-repeat-mode", repeatMode: "one" }],
    ["播完停止", { type: "set-repeat-mode", repeatMode: "none" }],
  ])("maps %s to exactly one native command", async (label, command) => {
    const dispatch = vi.fn().mockResolvedValue(true);
    render(<PlaybackModeControl snapshot={snapshot} busy={false} onDispatch={dispatch} />);
    await act(async () => fireEvent.click(screen.getByRole("button", { name: label as string })));
    expect(dispatch).toHaveBeenCalledExactlyOnceWith(command);
  });

  it("keeps committed selection after failure and supports Escape", async () => {
    const dispatch = vi.fn().mockResolvedValue(false);
    const { container } = render(<PlaybackModeControl snapshot={snapshot} busy={false} onDispatch={dispatch} />);
    await act(async () => fireEvent.click(screen.getByRole("button", { name: "随机播放" })));
    expect(screen.getByRole("button", { name: "顺序播放" })).toHaveAttribute("aria-pressed", "true");
    const details = container.querySelector("details");
    if (details === null) throw new Error("Missing mode control");
    details.open = true;
    fireEvent.keyDown(details, { key: "Escape" });
    expect(details.open).toBe(false);
    expect(details.querySelector("summary")).toHaveFocus();
  });
});
