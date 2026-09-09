import { describe, expect, it } from "vitest";

import {
  defaultHeniThemeId,
  heniThemes,
  parseHeniThemeId,
} from "./theme";

describe("Heni theme catalog", () => {
  it("accepts catalog ids and falls back for unknown external values", () => {
    expect(parseHeniThemeId("nocturne")).toBe("nocturne");
    expect(parseHeniThemeId("not-a-theme")).toBe(defaultHeniThemeId);
    expect(parseHeniThemeId(null)).toBe(defaultHeniThemeId);
  });

  it("keeps the intentionally small theme catalog uniquely identified", () => {
    expect(new Set(heniThemes.map((theme) => theme.id)).size).toBe(
      heniThemes.length,
    );
    expect(heniThemes.map((theme) => theme.label)).toEqual([
      "录音室",
      "深夜",
      "潮汐",
      "暮玫",
      "鸢尾",
      "余烬",
    ]);
  });
});
