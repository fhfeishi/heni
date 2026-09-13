import { defaultGlassSettings, glassFog, type GlassSettings } from "../../contracts/settings";
import { DraftActions } from "./DraftActions";

interface GlassControlProps {
  value: GlassSettings;
  dirty: boolean;
  disabled: boolean;
  onChange(value: GlassSettings): void;
  onSave(): void;
  onCancel(): void;
}

const materials = [
  { material: "clear", label: "清透", transparency: 70 },
  { material: "soft", label: "柔雾", transparency: 35 },
  { material: "frosted", label: "磨砂", transparency: 15 },
] as const;

export const GlassControl = ({ value, dirty, disabled, onChange, onSave, onCancel }: GlassControlProps) => (
  <fieldset className="scenery-control" disabled={disabled}>
    <legend>界面玻璃</legend>
    <div className="scenery-control__actions">
      {materials.map(({ material, label, transparency }) => (
        <button type="button" key={material} aria-pressed={value.material === material}
          onClick={() => onChange({ material, transparency })}>{label}</button>
      ))}
    </div>
    <label>通透度 · {value.transparency}%
      <input type="range" aria-label="玻璃通透度" min={0} max={100} step={1}
        value={value.transparency} onChange={(event) => onChange({ ...value, transparency: event.currentTarget.valueAsNumber })} />
    </label>
    <label>雾度 · {glassFog(value)}%
      <input type="range" aria-label="玻璃雾度" min={0} max={100} step={1}
        value={glassFog(value)} onChange={(event) => onChange({ ...value, fog: event.currentTarget.valueAsNumber })} />
    </label>
    <p className="scenery-control__hint">通透度调整底色，雾度调整模糊，不淡化文字。切换材质恢复该预设；保存后保留。</p>
    <DraftActions dirty={dirty} saveLabel="保存材质" cancelLabel="取消预览" onSave={onSave} onCancel={onCancel}
      reset={{ label: "恢复默认材质", onClick: () => onChange(defaultGlassSettings) }} />
  </fieldset>
);
