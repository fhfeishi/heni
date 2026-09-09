import { fireEvent, render, screen } from "@testing-library/react";
import { useState } from "react";
import { describe, expect, it } from "vitest";

import type { MediaDetails } from "../../contracts/library";

import { MediaDetailsPanel } from "./MediaDetailsPanel";

const details = {
  mediaId: "media-one",
  sourcePath: "C:\\Music\\one.flac",
  provider: "ffprobe" as const,
  formatName: "flac",
  formatLongName: "raw FLAC",
  durationMs: 60_000,
  sizeBytes: 8_192,
  bitRateBps: 65_536,
  streams: [],
  chapters: [],
  tags: {},
};

const Harness = () => {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button type="button" onClick={() => setOpen(true)}>
        打开详情
      </button>
      {open && (
        <MediaDetailsPanel details={details} onClose={() => setOpen(false)} />
      )}
    </>
  );
};

describe("MediaDetailsPanel", () => {
  it("presents Chinese stream labels while preserving codec and measurement facts", () => {
    const stream: MediaDetails["streams"][number] = {
      index: 0,
      kind: "audio",
      codecName: "FLAC",
      codecLongName: null,
      profile: null,
      width: null,
      height: null,
      sampleRateHz: 48_000,
      channels: 2,
      durationMs: 60_000,
      frameRate: null,
      bitRateBps: 960_000,
      tags: {},
    };
    render(
      <MediaDetailsPanel
        details={{
          ...details,
          streams: [
            stream,
            {
              ...stream,
              index: 1,
              kind: "video",
              codecName: "H.264",
              width: 1920,
              height: 1080,
              frameRate: "30",
            },
            { ...stream, index: 2, kind: "unknown", codecName: null },
          ],
        }}
        onClose={() => undefined}
      />,
    );

    expect(screen.getByText("文件信息")).toBeInTheDocument();
    expect(screen.getByText("流 0 · 音频")).toBeInTheDocument();
    expect(screen.getByText("流 1 · 视频")).toBeInTheDocument();
    expect(screen.getByText("流 2 · 其他")).toBeInTheDocument();
    expect(screen.getByText("未知编码")).toBeInTheDocument();
    expect(screen.getByText("FLAC")).toBeInTheDocument();
    expect(screen.getByText("H.264")).toBeInTheDocument();
    expect(
      screen.getByText(`${(48_000).toLocaleString()} Hz · 2 声道 · 960 kbps`),
    ).toBeInTheDocument();
    expect(screen.getByText("1920 × 1080 · 30 fps")).toBeInTheDocument();
    expect(screen.getByRole("dialog")).not.toHaveTextContent(/ON-DEMAND|FFPROBE/u);
  });

  it("owns focus, closes with Escape, and restores the invoking control", () => {
    render(<Harness />);
    const trigger = screen.getByRole("button", { name: "打开详情" });

    trigger.focus();
    fireEvent.click(trigger);
    const dialog = screen.getByRole("dialog", { name: "媒体详情" });
    expect(dialog).toHaveFocus();

    fireEvent.keyDown(dialog, { key: "Escape" });
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    expect(trigger).toHaveFocus();
  });

  it("keeps reverse tab navigation inside the details dialog", () => {
    render(<Harness />);
    fireEvent.click(screen.getByRole("button", { name: "打开详情" }));
    const dialog = screen.getByRole("dialog", { name: "媒体详情" });

    fireEvent.keyDown(dialog, { key: "Tab", shiftKey: true });
    expect(screen.getByRole("button", { name: "关闭" })).toHaveFocus();
  });
});
