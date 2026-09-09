import { describe, expect, it, vi } from "vitest";

import { createSettingsPort } from "./settingsPort";

const snapshot = {
  schemaVersion: 1,
  themeId: "nocturne",
  recursiveScan: true,
  includeVideo: false,
  autoplayOnLoad: false,
  sceneryIntensity: 100,
  sceneryAutoRotate: false,
} as const;

describe("createSettingsPort", () => {
  it("validates settings snapshots and sends partial updates", async () => {
    const invoke = vi.fn().mockResolvedValue(snapshot);
    const port = createSettingsPort(invoke);

    await expect(port.read()).resolves.toEqual({ ok: true, value: snapshot });
    await expect(port.update({ includeVideo: false })).resolves.toEqual({
      ok: true,
      value: snapshot,
    });
    expect(invoke).toHaveBeenNthCalledWith(1, "settings_snapshot");
    expect(invoke).toHaveBeenNthCalledWith(2, "settings_update", {
      request: { includeVideo: false },
    });
  });

  it("rejects empty updates before invoking Rust", async () => {
    const invoke = vi.fn();

    await expect(createSettingsPort(invoke).update({})).resolves.toEqual({
      ok: false,
      error: {
        code: "invalid-contract",
        message: "Settings update did not match the expected contract.",
      },
    });
    expect(invoke).not.toHaveBeenCalled();
  });

  it("rejects malformed snapshots and preserves structured command errors", async () => {
    const malformed = createSettingsPort(
      vi.fn().mockResolvedValue({ ...snapshot, themeId: "unknown" }),
    );
    const failed = createSettingsPort(
      vi.fn().mockRejectedValue({
        code: "database",
        message: "settings database unavailable",
      }),
    );

    expect((await malformed.read()).ok).toBe(false);
    await expect(failed.update({ recursiveScan: false })).resolves.toEqual({
      ok: false,
      error: {
        code: "database",
        message: "settings database unavailable",
      },
    });
  });
});
