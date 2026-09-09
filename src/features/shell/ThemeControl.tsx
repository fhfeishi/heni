import { heniThemes, parseHeniThemeId, type HeniThemeId } from "./theme";

export interface ThemeControlProps {
  themeId: HeniThemeId;
  disabled?: boolean;
  onSelect(themeId: HeniThemeId): void;
}

export const ThemeControl = ({
  themeId,
  disabled = false,
  onSelect,
}: ThemeControlProps) => (
  <label className="theme-control">
    <span>主题</span>
    <select
      aria-label="界面主题"
      value={themeId}
      disabled={disabled}
      onChange={(event) => onSelect(parseHeniThemeId(event.currentTarget.value))}
    >
      {heniThemes.map((theme) => (
        <option key={theme.id} value={theme.id}>
          {theme.label}
        </option>
      ))}
    </select>
  </label>
);
