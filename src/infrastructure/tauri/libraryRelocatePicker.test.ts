import { describe, expect, it, vi } from "vitest";

import type { LibraryItem } from "../../contracts/library";
import { createLibraryRelocatePicker } from "./libraryRelocatePicker";

const item = (kind: "audio" | "video"): LibraryItem => ({
  id: "stable-media-id",
  path: `C:\\Missing\\old.${kind === "audio" ? "flac" : "mp4"}`,
  title: kind === "audio" ? "old.flac" : "old.mp4",
  kind,
  durationMs: null,
  available: false,
  metadataStatus: "pending",
  fastMetadata: null,
});

describe("createLibraryRelocatePicker", () => {
  it("opens a single-file audio picker and returns the authorized path", async () => {
    const open = vi.fn().mockResolvedValue("D:\\Recovered\\new.flac");
    const picker = createLibraryRelocatePicker(open);

    await expect(picker.pickReplacement(item("audio"))).resolves.toEqual({
      ok: true,
      value: "D:\\Recovered\\new.flac",
    });
    expect(open).toHaveBeenCalledWith(
      expect.objectContaining({
        title: "为 old.flac 选择新文件",
        multiple: false,
        directory: false,
        filters: [
          expect.objectContaining({
            name: "Heni 支持的音频",
            extensions: expect.arrayContaining(["flac", "mp3", "opus"]),
          }),
        ],
      }),
    );
  });

  it("uses the video whitelist and preserves cancellation", async () => {
    const open = vi.fn().mockResolvedValue(null);
    const picker = createLibraryRelocatePicker(open);

    await expect(picker.pickReplacement(item("video"))).resolves.toEqual({
      ok: true,
      value: null,
    });
    expect(open).toHaveBeenCalledWith(
      expect.objectContaining({
        filters: [
          expect.objectContaining({
            name: "Heni 支持的视频",
            extensions: expect.arrayContaining(["mkv", "mp4", "webm"]),
          }),
        ],
      }),
    );
  });

  it("returns a structured transport error when the dialog fails", async () => {
    const picker = createLibraryRelocatePicker(
      vi.fn().mockRejectedValue(new Error("dialog failed")),
    );

    await expect(picker.pickReplacement(item("audio"))).resolves.toEqual({
      ok: false,
      error: { code: "transport", message: "dialog failed" },
    });
  });
});
