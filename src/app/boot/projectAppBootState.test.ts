import { describe, expect, it } from "vitest";

import { projectAppBootState } from "./projectAppBootState";

const available = { loading: false, available: true } as const;

describe("projectAppBootState", () => {
  it("boots until the runtime handshake and essential snapshots are ready", () => {
    expect(
      projectAppBootState({
        runtime: { status: "loading" },
        playback: available,
        library: available,
      }),
    ).toEqual({ status: "booting" });

    expect(
      projectAppBootState({
        runtime: {
          status: "ready",
          info: { appName: "Heni", appVersion: "0.1.0", platform: "windows" },
        },
        playback: { loading: true, available: false },
        library: available,
      }),
    ).toEqual({ status: "booting" });
  });

  it("treats a browser preview as an intentional degraded environment", () => {
    expect(
      projectAppBootState({
        runtime: {
          status: "failed",
          error: { code: "browser-preview", message: "preview" },
        },
        playback: { loading: false, available: false },
        library: { loading: false, available: false },
      }),
    ).toEqual({ status: "degraded", reason: "browser-preview" });
  });

  it.each([
    ["invalid-contract", "runtime-contract"],
    ["transport", "runtime-transport"],
  ] as const)("blocks a desktop runtime %s failure", (code, reason) => {
    expect(
      projectAppBootState({
        runtime: {
          status: "failed",
          error: { code, message: "unavailable" },
        },
        playback: available,
        library: available,
      }),
    ).toEqual({ status: "blocked", reason });
  });

  it("degrades when an essential snapshot is unavailable after startup", () => {
    expect(
      projectAppBootState({
        runtime: {
          status: "ready",
          info: { appName: "Heni", appVersion: "0.1.0", platform: "windows" },
        },
        playback: { loading: false, available: false },
        library: available,
      }),
    ).toEqual({
      status: "degraded",
      reason: "core-feature-unavailable",
    });
  });

  it("is ready only after both essential snapshots are available", () => {
    expect(
      projectAppBootState({
        runtime: {
          status: "ready",
          info: { appName: "Heni", appVersion: "0.1.0", platform: "windows" },
        },
        playback: available,
        library: available,
      }),
    ).toEqual({ status: "ready" });
  });
});
