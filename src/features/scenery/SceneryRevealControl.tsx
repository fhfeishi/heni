import { DraftActions } from "../settings/DraftActions";

interface SceneryRevealControlProps {
  value: number;
  dirty: boolean;
  disabled: boolean;
  onChange(value: number): void;
  onSave(): void;
  onCancel(): void;
}

export const SceneryRevealControl = ({ value, dirty, disabled, onChange, onSave, onCancel }: SceneryRevealControlProps) => (
  <fieldset className="scenery-control" disabled={disabled}>
    <legend>背景显露</legend>
    <label>原图显露 · {value}%
      <input aria-label="背景显露" type="range" min={0} max={300} step={1} value={value}
        onChange={(event) => onChange(event.currentTarget.valueAsNumber)} />
    </label>
    <p className="scenery-control__hint">0–100 保留原有显露效果；100–300 让中央内容逐渐退场，点击顶部“显示内容”可恢复操作。视频和播放控制不受影响，图片浓度为 0 时不启用沉浸。</p>
    <DraftActions dirty={dirty} saveLabel="保存显露" cancelLabel="取消显露预览" onSave={onSave} onCancel={onCancel}
      reset={{ label: "恢复原有遮罩", disabled: value === 0, onClick: () => onChange(0) }} />
  </fieldset>
);
