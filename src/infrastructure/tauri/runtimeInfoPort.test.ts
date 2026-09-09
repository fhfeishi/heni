import { describe, expect, it, vi } from "vitest";

import { readRuntimeInfo } from "./runtimeInfoPort";

describe("readRuntimeInfo", () => {
  it("returns validated runtime information", async () => {
    const invoke = vi.fn().mockResolvedValue({
      appName: "Heni",
      appVersion: "0.1.0",
      platform: "windows",
    });

    await expect(readRuntimeInfo(invoke)).resolves.toEqual({
      ok: true,
      value: {
        appName: "Heni",
        appVersion: "0.1.0",
        platform: "windows",
      },
    });
    expect(invoke).toHaveBeenCalledWith("runtime_info");
  });

  it("turns a malformed IPC payload into a typed error", async () => {
    const invoke = vi.fn().mockResolvedValue({ app_name: "Heni" });

    await expect(readRuntimeInfo(invoke)).resolves.toEqual({
      ok: false,
      error: {
        code: "invalid-contract",
        message: "Rust returned an unexpected runtime-info payload.",
      },
    });
  });

  it("identifies a browser preview without attempting desktop IPC", async () => {
    const invoke = vi.fn();

    await expect(readRuntimeInfo(invoke, "browser")).resolves.toEqual({
      ok: false,
      error: {
        code: "browser-preview",
        message: "The Tauri runtime is unavailable in a browser preview.",
      },
    });
    expect(invoke).not.toHaveBeenCalled();
  });
});
