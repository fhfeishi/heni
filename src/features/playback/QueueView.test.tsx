import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type { PlaybackItem, PlaybackSnapshot } from "../../contracts/playback";
import { QueueView } from "./QueueView";

const queue: ReadonlyArray<PlaybackItem> = [
  {
    id: "one",
    path: "C:\\Music\\One.flac",
    title: "One",
    kind: "audio",
    durationMs: 60_000,
  },
  {
    id: "two",
    path: "D:\\Archive\\Two.flac",
    title: "Two",
    kind: "audio",
    durationMs: 70_000,
  },
  {
    id: "three",
    path: "C:\\Music\\Three.flac",
    title: "Three",
    kind: "audio",
    durationMs: 80_000,
  },
];

const snapshot = (overrides: Partial<PlaybackSnapshot> = {}): PlaybackSnapshot => ({
  generation: 3,
  sequence: 7,
  status: "playing",
  queue,
  currentIndex: 0,
  positionMs: 10_000,
  durationMs: 60_000,
  volume: 70,
  muted: false,
  repeatMode: "all",
  shuffle: false,
  ...overrides,
});

const requiredRow = (
  rows: ReadonlyArray<HTMLElement>,
  index: number,
): HTMLElement => {
  const row = rows[index];
  if (row === undefined) {
    throw new Error(`Expected queue row ${index}.`);
  }
  return row;
};

describe("QueueView", () => {
  it("dispatches authoritative indexes after filtering", () => {
    const dispatch = vi.fn();
    render(<QueueView snapshot={snapshot()} busy={false} onDispatch={dispatch} />);

    fireEvent.change(screen.getByRole("searchbox", { name: "搜索队列" }), {
      target: { value: "archive" },
    });
    fireEvent.click(screen.getByRole("button", { name: "播放 Two" }));
    fireEvent.click(screen.getByRole("button", { name: "从队列移除 Two" }));

    expect(dispatch).toHaveBeenNthCalledWith(1, { type: "play-index", index: 1 });
    expect(dispatch).toHaveBeenNthCalledWith(2, { type: "remove-index", index: 1 });
    expect(screen.getByText("下一首")).toBeInTheDocument();
  });

  it("clears search and focuses the current item when locating", async () => {
    render(<QueueView snapshot={snapshot()} busy={false} onDispatch={vi.fn()} />);
    const search = screen.getByRole("searchbox", { name: "搜索队列" });

    fireEvent.change(search, { target: { value: "archive" } });
    fireEvent.click(screen.getByRole("button", { name: "定位当前项" }));

    await waitFor(() => {
      expect(search).toHaveValue("");
      expect(screen.getByRole("button", { name: "播放 One" })).toHaveFocus();
    });
  });

  it("requires a fresh confirmation before clearing the queue", () => {
    const dispatch = vi.fn();
    render(<QueueView snapshot={snapshot()} busy={false} onDispatch={dispatch} />);

    fireEvent.click(screen.getByRole("button", { name: "清空队列" }));
    expect(dispatch).not.toHaveBeenCalled();
    expect(screen.getByRole("alert")).toHaveTextContent("曲库和歌单不会被删除");

    fireEvent.click(screen.getByRole("button", { name: "确认清空队列" }));
    expect(dispatch).toHaveBeenCalledWith({
      type: "replace-queue",
      queue: [],
      currentIndex: null,
      autoplay: false,
    });
  });

  it("dispatches authoritative keyboard reorders and hides them while filtering", () => {
    const dispatch = vi.fn();
    render(<QueueView snapshot={snapshot()} busy={false} onDispatch={dispatch} />);

    fireEvent.click(screen.getByRole("button", { name: "上移 Two" }));
    expect(dispatch).toHaveBeenCalledWith({
      type: "reorder-queue",
      fromIndex: 1,
      toIndex: 0,
    });

    fireEvent.change(screen.getByRole("searchbox", { name: "搜索队列" }), {
      target: { value: "Two" },
    });
    expect(screen.queryByRole("button", { name: "上移 Two" })).toBeNull();
    expect(screen.getByText("1 / 3 项")).toBeInTheDocument();
  });

  it("dispatches a fresh drag reorder and drops a stale drag", () => {
    const dispatch = vi.fn();
    const { rerender } = render(
      <QueueView snapshot={snapshot()} busy={false} onDispatch={dispatch} />,
    );
    const dataTransfer = {
      effectAllowed: "none",
      dropEffect: "none",
      setData: vi.fn(),
    };
    let rows = screen.getAllByRole("listitem");

    fireEvent.dragStart(requiredRow(rows, 0), { dataTransfer });
    fireEvent.dragOver(requiredRow(rows, 2), { dataTransfer });
    fireEvent.drop(requiredRow(rows, 2), { dataTransfer });

    expect(dispatch).toHaveBeenCalledWith({
      type: "reorder-queue",
      fromIndex: 0,
      toIndex: 2,
    });
    dispatch.mockClear();

    rows = screen.getAllByRole("listitem");
    fireEvent.dragStart(requiredRow(rows, 0), { dataTransfer });
    rerender(
      <QueueView
        snapshot={snapshot({ sequence: 8 })}
        busy={false}
        onDispatch={dispatch}
      />,
    );
    rows = screen.getAllByRole("listitem");
    fireEvent.drop(requiredRow(rows, 2), { dataTransfer });

    expect(dispatch).not.toHaveBeenCalled();
  });
});
