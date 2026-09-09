import { describe, expect, it } from "vitest";

import { defaultSettingsSnapshot, settingsSnapshotSchema, settingsUpdateSchema } from "./settings";

describe("scenery intensity contract", () => {
  it("keeps reveal optional for older snapshots and validates partial writes", () => {
    expect(settingsSnapshotSchema.parse({ ...defaultSettingsSnapshot, sceneryReveal: undefined }).sceneryReveal).toBeUndefined();
    expect(settingsUpdateSchema.parse({ sceneryReveal: 100 })).toEqual({ sceneryReveal: 100 });
    expect(settingsUpdateSchema.parse({ sceneryReveal: 300 })).toEqual({ sceneryReveal: 300 });
    expect(settingsSnapshotSchema.parse({ ...defaultSettingsSnapshot, sceneryReveal: 256 }).sceneryReveal).toBe(256);
    for (const sceneryReveal of [-1, 301, 0.5, NaN]) {
      expect(settingsUpdateSchema.safeParse({ sceneryReveal }).success).toBe(false);
    }
    expect(settingsUpdateSchema.parse({ themeId: "tide" })).toEqual({ themeId: "tide" });
  });
  it("validates glass as a whole preference without injecting it into theme updates", () => {
    expect(settingsUpdateSchema.parse({ glass: { material: "clear", transparency: 100 } })).toEqual({ glass: { material: "clear", transparency: 100 } });
    for (const glass of [{ material: "unknown", transparency: 30 }, { material: "soft", transparency: 101 }, { material: "soft", transparency: -1 }, { material: "soft", transparency: 1.5 }]) {
      expect(settingsUpdateSchema.safeParse({ glass }).success).toBe(false);
    }
    expect(settingsUpdateSchema.parse({ themeId: "rose" })).toEqual({ themeId: "rose" });
  });
  it("reads older snapshots without changing existing appearance", () => {
    const legacy = { ...defaultSettingsSnapshot, sceneryIntensity: undefined };
    expect(settingsSnapshotSchema.parse(legacy).sceneryIntensity).toBe(100);
    expect(settingsSnapshotSchema.parse({ ...legacy, sceneryAutoRotate: undefined }).sceneryAutoRotate).toBe(false);
  });

  it.each([-1, 101, 1.5, NaN, Infinity])("rejects invalid intensity %s", (value) => {
    expect(settingsUpdateSchema.safeParse({ sceneryIntensity: value }).success).toBe(false);
  });

  it("does not inject intensity into unrelated partial updates", () => {
    expect(settingsUpdateSchema.parse({ themeId: "tide" })).toEqual({ themeId: "tide" });
    expect(settingsUpdateSchema.safeParse({}).success).toBe(false);
    expect(settingsUpdateSchema.parse({ sceneryIntensity: 0 })).toEqual({ sceneryIntensity: 0 });
  });
});
