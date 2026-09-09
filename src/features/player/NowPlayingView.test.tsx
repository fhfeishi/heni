import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { NowPlayingView } from "./NowPlayingView";

describe("NowPlayingView", () => {
  it("presents real indexed metadata and the on-demand details action", () => {
    const inspect = vi.fn();
    const longTitle =
      "一首标题很长但必须保持稳定布局的本地音乐作品.flac";
    const currentItem = {
      id: "c:\\music\\long.flac",
      path: "C:\\音乐\\很长的目录\\long.flac",
      title: longTitle,
      kind: "audio" as const,
      durationMs: 60_000,
    };

    render(
      <NowPlayingView
        currentItem={currentItem}
        currentLibraryItem={{
          ...currentItem,
          available: true,
          metadataStatus: "indexed",
          fastMetadata: {
            codecName: "flac",
            sampleRateHz: 48_000,
            channels: 2,
            bitsPerSample: 24,
            fileSizeBytes: 8_192,
            estimatedBitRateBps: 1_411_200,
          },
        }}
        nextItem={{
          id: "c:\\music\\next.flac",
          path: "C:\\Music\\next.flac",
          title: "next.flac",
          kind: "audio",
          durationMs: null,
        }}
        status="paused"
        picking={false}
        busy={false}
        loadingDetails={false}
        onChooseFiles={vi.fn()}
        onChooseDirectory={vi.fn()}
        onOpenLibrary={vi.fn()}
        onInspectDetails={inspect}
      />,
    );

    expect(screen.getByText(longTitle)).toBeInTheDocument();
    expect(screen.getByText("已暂停")).toBeInTheDocument();
    expect(screen.queryByText(currentItem.path)).toBeNull();
    fireEvent.click(screen.getByText("音频信息"));
    expect(screen.getByText("FLAC")).toBeInTheDocument();
    expect(screen.getByText("48,000 Hz")).toBeInTheDocument();
    expect(screen.getByText("2 声道")).toBeInTheDocument();
    expect(screen.getByText("24 bit")).toBeInTheDocument();
    expect(screen.getByText("next.flac")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "媒体详情" }));
    expect(inspect).toHaveBeenCalledOnce();
  });

  it("keeps the empty playback state free of invented media facts", () => {
    render(
      <NowPlayingView
        currentItem={null}
        currentLibraryItem={null}
        nextItem={null}
        status="idle"
        picking={false}
        busy={false}
        loadingDetails={false}
        onChooseFiles={vi.fn()}
        onChooseDirectory={vi.fn()}
        onOpenLibrary={vi.fn()}
        onInspectDetails={vi.fn()}
      />,
    );

    expect(
      screen.getByRole("heading", { name: "开始聆听" }),
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "媒体详情" })).toBeNull();
    expect(screen.getByText("队列中没有下一首")).toBeInTheDocument();
    expect(screen.getByText("聆听时刻")).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "从一首歌开始" }),
    ).toBeInTheDocument();
    expect(screen.queryByText(/^H$/u)).toBeNull();
  });

  it.each([
    ["loading", "正在载入"],
    ["playing", "正在播放"],
    ["paused", "已暂停"],
    ["stopped", "已停止"],
    ["completed", "播放完成"],
    ["failed", "播放失败"],
  ] as const)("maps %s to stable product copy", (status, expectedCopy) => {
    const { container } = render(
      <NowPlayingView
        currentItem={{
          id: "c:\\music\\one.flac",
          path: "C:\\Music\\one.flac",
          title: "one.flac",
          kind: "audio",
          durationMs: null,
        }}
        currentLibraryItem={null}
        nextItem={null}
        status={status}
        picking={false}
        busy={false}
        loadingDetails={false}
        onChooseFiles={vi.fn()}
        onChooseDirectory={vi.fn()}
        onOpenLibrary={vi.fn()}
        onInspectDetails={vi.fn()}
      />,
    );

    expect(container.querySelector(".playback-state")).toHaveTextContent(
      expectedCopy,
    );
  });
});
