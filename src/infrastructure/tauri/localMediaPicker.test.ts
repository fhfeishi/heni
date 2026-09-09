import { describe, expect, it, vi } from "vitest";

import { createLocalMediaPicker } from "./localMediaPicker";

describe("createLocalMediaPicker", () => {
  it("classifies supported video containers without misclassifying audio", async () => {
    const picker = createLocalMediaPicker(vi.fn().mockResolvedValue(["C:/MV/live.MP4", "C:/MV/live.webm", "C:/Music/song.m4a"]));
    const result = await picker.pickAudioFiles();
    expect(result.ok && result.value.map((item) => item.kind)).toEqual(["video", "video", "audio"]);
  });
  it("turns one Windows path into a typed audio item", async () => {
    const openDialog = vi
      .fn()
      .mockResolvedValue(["C:\\Music\\周末 mix.flac"]);
    const picker = createLocalMediaPicker(openDialog);

    await expect(picker.pickAudioFiles()).resolves.toEqual({
      ok: true,
      value: [{
        id: "C:\\Music\\周末 mix.flac",
        path: "C:\\Music\\周末 mix.flac",
        title: "周末 mix.flac",
        kind: "audio",
        durationMs: null,
      }],
    });
    expect(openDialog).toHaveBeenCalledWith(
      expect.objectContaining({ multiple: true, directory: false }),
    );
  });

  it("treats cancellation as a successful empty selection", async () => {
    const picker = createLocalMediaPicker(vi.fn().mockResolvedValue(null));

    await expect(picker.pickAudioFiles()).resolves.toEqual({
      ok: true,
      value: [],
    });
  });

  it("deduplicates Windows paths before they reach the queue contract", async () => {
    const picker = createLocalMediaPicker(
      vi
        .fn()
        .mockResolvedValue(["C:\\Music\\one.flac", "c:/music/ONE.flac"]),
    );

    const result = await picker.pickAudioFiles();

    expect(result.ok && result.value).toHaveLength(1);
  });
});
