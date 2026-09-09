import { DraftActions } from "../settings/DraftActions";

interface SceneryIntensityControlProps {
  value: number;
  dirty: boolean;
  disabled: boolean;
  onChange(value: number): void;
  onSave(): void;
  onCancel(): void;
}

export const SceneryIntensityControl = ({
  value,
  dirty,
  disabled,
  onChange,
  onSave,
  onCancel,
}: SceneryIntensityControlProps) => (
  <fieldset className="scenery-control" disabled={disabled}>
    <legend>背景强度</legend>
    <label>
      图片浓度 · {value}%
      <input
        aria-label="背景强度"
        type="range"
        min={0}
        max={100}
        step={1}
        value={value}
        onChange={(event) => onChange(event.currentTarget.valueAsNumber)}
      />
    </label>
    <p className="scenery-control__hint">
      拖动预览，保存后下次打开仍保留。0% 只显示主题底色。
    </p>
    <DraftActions dirty={dirty} saveLabel="保存强度" cancelLabel="取消调整" onSave={onSave} onCancel={onCancel} />
  </fieldset>
);
