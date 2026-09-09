import { describe, expect, it, vi } from "vitest";

import { createWindowPort } from "./windowPort";

const snapshot = {
  mode: "main",
  maximized: false,
  alwaysOnTop: false,
  innerWidth: 1180,
  innerHeight: 760,
  scaleFactor: 1.25,
};

describe("createWindowPort", () => {
  it("keeps Tauri command details behind a typed facade", async () => {
    const invoke = vi.fn().mockResolvedValue(snapshot);
    const port = createWindowPort(invoke);

    await expect(port.read()).resolves.toEqual({ ok: true, value: snapshot });
    await expect(port.setMode("mini-player")).resolves.toEqual({
      ok: true,
      value: snapshot,
    });
    expect(invoke.mock.calls).toEqual([
      ["window_snapshot", undefined],
      ["window_set_mode", { mode: "mini-player" }],
    ]);
  });

  it("rejects malformed snapshots before they reach React", async () => {
    const port = createWindowPort(vi.fn().mockResolvedValue({ mode: "main" }));

    await expect(port.read()).resolves.toEqual({
      ok: false,
      error: {
        code: "invalid-contract",
        message: "Rust returned an unexpected window snapshot.",
      },
    });
  });

  it("preserves structured Rust window errors", async () => {
    const port = createWindowPort(
      vi.fn().mockRejectedValue({
        code: "window-unavailable",
        message: "window failed",
      }),
    );

    await expect(port.setMode("mini-player")).resolves.toEqual({
      ok: false,
      error: { code: "window-unavailable", message: "window failed" },
    });
  });
});
