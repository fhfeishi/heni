import { describe, expect, it, vi } from "vitest";

import { createFileActionPort } from "./fileActionPort";

describe("createFileActionPort", () => {
  it("sends only the stable media id and accepts the Rust unit response", async () => {
    const invoke = vi.fn().mockResolvedValue(null);

    await expect(
      createFileActionPort(invoke).revealMedia("media-中文-1"),
    ).resolves.toEqual({ ok: true, value: undefined });
    expect(invoke).toHaveBeenCalledWith("file_action_reveal_media", {
      request: { mediaId: "media-中文-1" },
    });
  });

  it("rejects an unexpected success payload at the IPC boundary", async () => {
    const invoke = vi.fn().mockResolvedValue({ path: "C:\\Private\\song.flac" });

    await expect(
      createFileActionPort(invoke).revealMedia("media-one"),
    ).resolves.toEqual({
      ok: false,
      error: {
        code: "invalid-contract",
        message: "Rust returned an unexpected file action payload.",
      },
    });
  });

  it("preserves validated command errors and normalizes transport failures", async () => {
    const structuredInvoke = vi.fn().mockRejectedValue({
      code: "file-unavailable",
      message: "The selected media file is no longer available.",
    });
    const transportInvoke = vi.fn().mockRejectedValue(new Error("invoke failed"));

    await expect(
      createFileActionPort(structuredInvoke).revealMedia("missing"),
    ).resolves.toEqual({
      ok: false,
      error: {
        code: "file-unavailable",
        message: "The selected media file is no longer available.",
      },
    });
    await expect(
      createFileActionPort(transportInvoke).revealMedia("media-one"),
    ).resolves.toEqual({
      ok: false,
      error: { code: "transport", message: "invoke failed" },
    });
  });
});
