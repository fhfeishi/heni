import { act, renderHook } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { ok } from "../../contracts/result";
import {
  defaultSettingsSnapshot,
  type SettingsPort,
  type SettingsSnapshot,
  type SettingsUpdate,
} from "../../contracts/settings";
import { useSettings } from "./useSettings";

const mergeSettings = (
  current: SettingsSnapshot,
  update: SettingsUpdate,
): SettingsSnapshot => ({
  schemaVersion: 1,
  themeId: update.themeId ?? current.themeId,
  recursiveScan: update.recursiveScan ?? current.recursiveScan,
  includeVideo: update.includeVideo ?? current.includeVideo,
  autoplayOnLoad: update.autoplayOnLoad ?? current.autoplayOnLoad,
  sceneryIntensity: update.sceneryIntensity ?? current.sceneryIntensity,
  sceneryAutoRotate: update.sceneryAutoRotate ?? current.sceneryAutoRotate,
});

describe("useSettings", () => {
  it("loads persisted settings and projects committed updates", async () => {
    const restored = {
      ...defaultSettingsSnapshot,
      themeId: "tide" as const,
      includeVideo: false,
    };
    const port: SettingsPort = {
      read: async () => ok(restored),
      update: async (request) => ok(mergeSettings(restored, request)),
    };
    const { result } = renderHook(() => useSettings(port));

    await act(async () => undefined);
    expect(result.current.snapshot).toEqual(restored);

    await act(async () => {
      await result.current.update({ autoplayOnLoad: false });
    });
    expect(result.current.snapshot.autoplayOnLoad).toBe(false);
    expect(result.current.error).toBeNull();
  });

  it("keeps the last committed snapshot when persistence fails", async () => {
    const port: SettingsPort = {
      read: async () => ok(defaultSettingsSnapshot),
      update: async () => ({
        ok: false,
        error: { code: "database", message: "database unavailable" },
      }),
    };
    const { result } = renderHook(() => useSettings(port));
    await act(async () => undefined);

    await act(async () => {
      await result.current.update({ themeId: "nocturne" });
    });
    expect(result.current.snapshot.themeId).toBe("studio");
    expect(result.current.error?.code).toBe("database");
  });
});
