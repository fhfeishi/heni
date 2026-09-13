import { describe, expect, it } from "vitest";
import { glassStyle } from "./glass";

describe("glass style", () => {
  it("keeps local backing at both endpoints and never changes content opacity", () => {
    expect(glassStyle({ material: "clear", transparency: 100 })).toEqual({ "--glass-fill": "40%", "--glass-blur": "4px" });
    expect(glassStyle({ material: "frosted", transparency: 0 })).toEqual({ "--glass-fill": "94%", "--glass-blur": "28px" });
  });
  it("adjusts fog without changing surface opacity", () => {
    expect(glassStyle({ material: "soft", transparency: 100, fog: 100 })).toEqual({ "--glass-fill": "40%", "--glass-blur": "40px" });
    expect(glassStyle({ material: "soft", transparency: 100, fog: 0 })).toEqual({ "--glass-fill": "40%", "--glass-blur": "0px" });
  });
});
