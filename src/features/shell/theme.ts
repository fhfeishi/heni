import {
  heniThemeIdSchema,
  type HeniThemeId,
} from "../../contracts/settings";

export const heniThemes = [
  { id: "studio", label: "录音室", colors: "#172119, #a8cf7b" },
  { id: "nocturne", label: "深夜", colors: "#172224, #e6cb86" },
  { id: "tide", label: "潮汐", colors: "#172433, #f1ca88" },
  { id: "rose", label: "暮玫", colors: "#302028, #edb3bd" },
  { id: "iris", label: "鸢尾", colors: "#242239, #bdb3ee" },
  { id: "ember", label: "余烬", colors: "#30251e, #edbd90" },
] as const;

export type { HeniThemeId } from "../../contracts/settings";

export const defaultHeniThemeId: HeniThemeId = "studio";

export const parseHeniThemeId = (value: unknown): HeniThemeId => {
  const parsed = heniThemeIdSchema.safeParse(value);
  return parsed.success ? parsed.data : defaultHeniThemeId;
};
