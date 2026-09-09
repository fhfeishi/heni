import { describe, expect, it } from "vitest";
import { sceneryImmersion, sceneryPresentation } from "./sceneryPresentation";

describe("scenery presentation", () => {
  it("extends immersion without opacity values above one", () => {
    expect(sceneryImmersion(100)).toBe(0);
    expect(sceneryImmersion(200)).toBe(0.5);
    expect(sceneryImmersion(300)).toBe(1);
    expect(sceneryImmersion(999)).toBe(1);
    expect(sceneryImmersion(NaN)).toBe(0);
    expect(sceneryPresentation(false, 300)).toMatchObject({ "--scenery-image-opacity": 1,
      "--scenery-image-shade": "0%", "--scenery-blur": "0px" });
  });
  it("preserves legacy endpoints when reveal is zero", () => {
    expect(sceneryPresentation(true, 0)).toMatchObject({ "--scenery-image-opacity": 0.72, "--scenery-image-shade": "52%", "--scenery-blur": "2px" });
    expect(sceneryPresentation(false, 0)).toMatchObject({ "--scenery-image-opacity": 0.42, "--scenery-image-shade": "64%" });
  });
  it("removes stage-wide scrims but protects browse text", () => {
    expect(sceneryPresentation(true, 100)).toMatchObject({ "--scenery-image-opacity": 1, "--scenery-image-shade": "0%", "--scenery-top-shade": "0%", "--scenery-bottom-shade": "0%", "--scenery-blur": "0px" });
    expect(sceneryPresentation(false, 100)).toMatchObject({ "--scenery-image-shade": "45%", "--scenery-blur": "3px" });
  });
  it("bounds presentation inputs without changing content opacity", () => {
    expect(sceneryPresentation(true, Infinity)).toEqual(sceneryPresentation(true, 0));
    expect(sceneryPresentation(true, -1)).toEqual(sceneryPresentation(true, 0));
    expect(sceneryPresentation(true, 101)).toEqual(sceneryPresentation(true, 100));
    expect(sceneryPresentation(true, 100)).not.toHaveProperty("opacity");
  });
});
