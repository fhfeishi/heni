import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type { LibraryItem } from "../../contracts/library";
import { LibraryItemRow } from "./LibraryItemRow";

const media: LibraryItem = {
  id: "one",
  title: "一首音乐.flac",
  path: "C:\\音乐\\一首音乐.flac",
  kind: "audio",
  available: true,
  durationMs: null,
  metadataStatus: "indexed",
  fastMetadata: {
    codecName: null,
    sampleRateHz: 48_000,
    channels: 2,
    bitsPerSample: null,
    fileSizeBytes: 8192,
    estimatedBitRateBps: null,
  },
};

const renderItem = (item: LibraryItem) =>
  render(
    <ul>
      <LibraryItemRow
        item={item}
        busy={false}
        loadingDetails={false}
        relocating={false}
        revealing={false}
        onInspect={vi.fn()}
        onPlay={vi.fn()}
        onPlayNext={vi.fn()}
        onEnqueue={vi.fn()}
        onRelocate={vi.fn()}
        onReveal={vi.fn()}
      />
    </ul>,
  );

describe("LibraryItemRow", () => {
  it("omits unknown codec fields without leaving leading separators", () => {
    renderItem(media);
    expect(screen.getByText("48,000 Hz · 2 声道")).toBeInTheDocument();
    expect(screen.queryByText(media.path)).toBeNull();
    expect(screen.getByText(media.title)).toHaveAttribute("title", media.title);
  });

  it.each([
    ["pending", "文件信息待补充"],
    ["failed", "暂未读取文件信息 · 可查看详情"],
  ] as const)(
    "preserves the %s information state in compact rows",
    (metadataStatus, copy) => {
      renderItem({ ...media, fastMetadata: null, metadataStatus });
      expect(screen.getByText(copy)).toBeInTheDocument();
      expect(screen.queryByText(/undefined|FLAC/u)).toBeNull();
    },
  );
});
