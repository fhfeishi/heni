import { describe, expect, it } from "vitest";

import { scenerySnapshotSchema } from "./scenery";

describe("scenery contract", () => {
  it("bounds collection positions without accepting private path lists", () => {
    const snapshot = { state: "unavailable", fileName: "image.png", reason: "file-unavailable" };
    expect(scenerySnapshotSchema.safeParse({ ...snapshot, collection: { index: 1, count: 2 } }).success).toBe(true);
    for (const collection of [{ index: 2, count: 2 }, { index: 0, count: 13 }, { index: -1, count: 1 }, { index: 0, count: 1, paths: ["private"] }]) {
      expect(scenerySnapshotSchema.safeParse({ ...snapshot, collection }).success).toBe(false);
    }
  });
  it("distinguishes no selection from an unavailable saved selection", () => {
    expect(scenerySnapshotSchema.safeParse({ state: "empty" }).success).toBe(
      true,
    );
    expect(
      scenerySnapshotSchema.safeParse({
        state: "unavailable",
        fileName: "海岸.png",
        reason: "file-unavailable",
      }).success,
    ).toBe(true);
  });

  it("accepts only bounded inline PNG or JPEG images", () => {
    for (const dataUrl of [
      "data:image/png;base64,AQID",
      "data:image/jpeg;base64,AQID",
    ]) {
      expect(
        scenerySnapshotSchema.safeParse({
          state: "ready",
          fileName: "海岸.png",
          dataUrl,
        }).success,
      ).toBe(true);
    }
    for (const dataUrl of [
      "https://example.com/image.png",
      "file:///private/image.jpg",
      "data:image/svg+xml;base64,AQID",
      "data:image/png;base64,",
      "data:image/png;base64,A!ID",
    ]) {
      expect(
        scenerySnapshotSchema.safeParse({
          state: "ready",
          fileName: "image",
          dataUrl,
        }).success,
      ).toBe(false);
    }
  });

  it("rejects inconsistent states, paths, and unrecognized error reasons", () => {
    for (const value of [
      { state: "ready", fileName: "image.png" },
      { state: "empty", path: "private/path" },
      {
        state: "unavailable",
        fileName: "image.png",
        reason: "private diagnostic",
      },
    ]) {
      expect(scenerySnapshotSchema.safeParse(value).success).toBe(false);
    }
  });
});
