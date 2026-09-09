import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type { LibraryItem } from "../../contracts/library";
import { LibraryPanel, type LibraryPanelProps } from "./LibraryPanel";

const item = (
  id: string,
  title: string,
  kind: "audio" | "video",
  available = true,
): LibraryItem => ({
  id,
  path: `C:\\音乐\\很长的目录\\${title}`,
  title,
  kind,
  durationMs: null,
  available,
  metadataStatus: "indexed",
  fastMetadata: {
    codecName: kind === "audio" ? "flac" : "h264",
    sampleRateHz: kind === "audio" ? 48_000 : null,
    channels: kind === "audio" ? 2 : null,
    bitsPerSample: kind === "audio" ? 24 : null,
    fileSizeBytes: 8_192,
    estimatedBitRateBps: null,
  },
});

describe("LibraryPanel", () => {
  const emptyProps = (): LibraryPanelProps => ({
    items: [],
    loading: false,
    busy: false,
    scan: null,
    legacyImportStatus: null,
    loadingDetailsMediaId: null,
    relocatingMediaId: null,
    revealingMediaId: null,
    onChooseDirectory: vi.fn(),
    onImportLegacy: vi.fn(),
    onCancelScan: vi.fn(),
    onInspect: vi.fn(),
    onPlay: vi.fn(),
    onPlayNext: vi.fn(),
    onEnqueue: vi.fn(),
    onRelocate: vi.fn(),
    onReveal: vi.fn(),
  });

  it("explains the empty library without exposing database implementation terms", () => {
    const { container } = render(<LibraryPanel {...emptyProps()} />);
    expect(screen.getByText(/还没有收录音乐/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "导入文件夹" })).toBeEnabled();
    expect(container).not.toHaveTextContent(/SQLite|事务/i);
  });

  it.each(["finished", "failed"] as const)(
    "shows %s without an obsolete cancellation action",
    (phase) => {
      render(
        <LibraryPanel
          {...emptyProps()}
          scan={{
            scanId: "scan-1",
            phase,
            visited: 8,
            matched: 6,
            unreadable: 2,
          }}
        />,
      );
      expect(
        screen.getByText(phase === "failed" ? /扫描未完成/ : /扫描已结束/),
      ).toBeInTheDocument();
      expect(screen.queryByRole("button", { name: "取消扫描" })).toBeNull();
    },
  );

  it("filters locally without invoking persistence or playback actions", () => {
    const chooseDirectory = vi.fn();
    const play = vi.fn();
    const inspect = vi.fn();
    const playNext = vi.fn();
    const enqueue = vi.fn();
    const reveal = vi.fn();

    render(
      <LibraryPanel
        items={[
          item("alpha", "Alpha.flac", "audio"),
          item("movie", "电影.mp4", "video"),
          item("missing", "Missing.flac", "audio", false),
        ]}
        loading={false}
        busy={false}
        scan={null}
        legacyImportStatus={null}
        loadingDetailsMediaId={null}
        relocatingMediaId={null}
        revealingMediaId={null}
        onChooseDirectory={chooseDirectory}
        onImportLegacy={vi.fn()}
        onCancelScan={vi.fn()}
        onInspect={inspect}
        onPlay={play}
        onPlayNext={playNext}
        onEnqueue={enqueue}
        onRelocate={vi.fn()}
        onReveal={reveal}
      />,
    );

    fireEvent.change(screen.getByRole("searchbox", { name: "搜索" }), {
      target: { value: "电影" },
    });
    expect(screen.getByText("电影.mp4")).toBeInTheDocument();
    expect(screen.queryByText("Alpha.flac")).toBeNull();

    fireEvent.change(screen.getByLabelText("文件状态"), {
      target: { value: "missing" },
    });
    expect(screen.getByText("没有符合筛选条件的媒体")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "清除筛选" }));
    expect(screen.getByText("Alpha.flac")).toBeInTheDocument();
    expect(screen.getByText("文件缺失")).toBeInTheDocument();
    expect(
      screen.getByText("原曲库与歌单引用已保留 · 等待重新定位"),
    ).toBeInTheDocument();
    expect(chooseDirectory).not.toHaveBeenCalled();
    expect(play).not.toHaveBeenCalled();
    expect(inspect).not.toHaveBeenCalled();
    expect(playNext).not.toHaveBeenCalled();
    expect(enqueue).not.toHaveBeenCalled();
    expect(reveal).not.toHaveBeenCalled();
  });

  it("keeps playback primary and exposes secondary row actions on demand", () => {
    const alpha = item("alpha", "Alpha.flac", "audio");
    const play = vi.fn();
    const inspect = vi.fn();
    const playNext = vi.fn();
    const enqueue = vi.fn();
    const reveal = vi.fn();

    render(
      <LibraryPanel
        items={[alpha]}
        loading={false}
        busy={false}
        scan={null}
        legacyImportStatus={null}
        loadingDetailsMediaId={null}
        relocatingMediaId={null}
        revealingMediaId={null}
        onChooseDirectory={vi.fn()}
        onImportLegacy={vi.fn()}
        onCancelScan={vi.fn()}
        onInspect={inspect}
        onPlay={play}
        onPlayNext={playNext}
        onEnqueue={enqueue}
        onRelocate={vi.fn()}
        onReveal={reveal}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "播放 Alpha.flac" }));
    expect(play).toHaveBeenCalledWith(alpha);
    expect(
      screen.queryByRole("button", { name: "加入队列 Alpha.flac" }),
    ).toBeNull();
    expect(screen.queryByText(alpha.path)).toBeNull();
    expect(screen.getByText("FLAC · 48,000 Hz · 2 声道")).toBeInTheDocument();

    fireEvent.click(
      screen.getByRole("button", { name: "更多操作 Alpha.flac" }),
    );
    expect(screen.getByText(alpha.path)).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "查看 Alpha.flac 的媒体详情" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "下一首播放 Alpha.flac" }),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "加入队列 Alpha.flac" }),
    );
    fireEvent.click(
      screen.getByRole("button", {
        name: "在资源管理器中显示 Alpha.flac",
      }),
    );

    expect(inspect).toHaveBeenCalledOnce();
    expect(playNext).toHaveBeenCalledOnce();
    expect(enqueue).toHaveBeenCalledOnce();
    expect(reveal).toHaveBeenCalledWith(alpha);
    fireEvent.click(
      screen.getByRole("button", { name: "更多操作 Alpha.flac" }),
    );
    expect(screen.queryByText(alpha.path)).toBeNull();
  });

  it("offers relocation as the primary recovery for a missing item", () => {
    const missing = item("missing", "Missing.flac", "audio", false);
    const relocate = vi.fn();

    render(
      <LibraryPanel
        items={[missing]}
        loading={false}
        busy={false}
        scan={null}
        legacyImportStatus={null}
        loadingDetailsMediaId={null}
        relocatingMediaId={null}
        revealingMediaId={null}
        onChooseDirectory={vi.fn()}
        onImportLegacy={vi.fn()}
        onCancelScan={vi.fn()}
        onInspect={vi.fn()}
        onPlay={vi.fn()}
        onPlayNext={vi.fn()}
        onEnqueue={vi.fn()}
        onRelocate={relocate}
        onReveal={vi.fn()}
      />,
    );

    fireEvent.click(
      screen.getByRole("button", { name: "重新定位 Missing.flac" }),
    );
    expect(relocate).toHaveBeenCalledWith(missing);
    expect(
      screen.getByRole("button", { name: "重新定位 Missing.flac" }),
    ).toBeEnabled();
    fireEvent.click(
      screen.getByRole("button", { name: "更多操作 Missing.flac" }),
    );
    expect(
      screen.getByRole("button", {
        name: "在资源管理器中显示 Missing.flac",
      }),
    ).toBeDisabled();
  });
});
