import { describe, expect, it } from "vitest";

import { windowSnapshotSchema } from "./window";

describe("windowSnapshotSchema", () => {
  it("accepts a validated desktop window snapshot", () => {
    expect(
      windowSnapshotSchema.parse({
        mode: "mini-player",
        maximized: false,
        alwaysOnTop: true,
        innerWidth: 420,
        innerHeight: 236,
        scaleFactor: 1.5,
      }),
    ).toEqual({
      mode: "mini-player",
      maximized: false,
      alwaysOnTop: true,
      innerWidth: 420,
      innerHeight: 236,
      scaleFactor: 1.5,
    });
  });

  it("rejects an unknown mode and impossible scale factor", () => {
    expect(
      windowSnapshotSchema.safeParse({
        mode: "floating",
        maximized: false,
        alwaysOnTop: false,
        innerWidth: 420,
        innerHeight: 236,
        scaleFactor: 0,
      }).success,
    ).toBe(false);
  });
});
