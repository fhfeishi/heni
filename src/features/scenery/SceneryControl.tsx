import type { SceneryError, ScenerySnapshot } from "../../contracts/scenery";

interface SceneryControlProps {
  snapshot: ScenerySnapshot;
  loading: boolean;
  busy: boolean;
  error: SceneryError | null;
  preview: boolean;
  onChoose(): void;
  onClear(): void;
  canStep?: boolean;
  onNext?(): void;
  onPrevious?(): void;
  autoRotate?: boolean;
  rotationBusy?: boolean;
  onAutoRotateChange?(enabled: boolean): void;
}

const errorCopy: Readonly<Record<SceneryError, string>> = {
  busy: "正在处理另一项美景设置，请稍后重试。",
  database: "美景设置暂未保存，原来的选择保持不变。",
  "file-unavailable": "图片已移动或暂时无法读取，请重新选择。",
  "unsupported-image": "图片无法显示，请选择完整的静态 PNG 或 JPEG 图片。",
  "image-too-large":
    "图片过大或解码占用过高。请选择 8 MiB 以内、单边不超过 8192 像素且不超过 2400 万像素的图片。",
  "collection-too-large": "一次最多选择 12 张图片，文件合计不超过 64 MiB。原场景保持不变。",
  internal: "美景设置暂不可用，请稍后重试。",
  transport: "暂时无法读取美景设置，播放和曲库不受影响。",
  "invalid-contract": "美景设置暂不可用，已保留主题背景。",
};

export const SceneryControl = ({
  snapshot,
  loading,
  busy,
  error,
  preview,
  onChoose,
  onClear,
  canStep = false,
  onNext,
  onPrevious,
  autoRotate = false,
  rotationBusy = false,
  onAutoRotateChange,
}: SceneryControlProps) => {
  const issue =
    error ?? (snapshot.state === "unavailable" ? snapshot.reason : null);
  return (
    <fieldset className="scenery-control" disabled={loading || busy || preview}>
      <legend>美景背景</legend>
      <p
        className="scenery-control__selection"
        title={snapshot.state === "empty" ? undefined : snapshot.fileName}
      >
        {loading
          ? "正在读取背景…"
          : snapshot.state === "empty"
            ? "跟随主题，不使用图片"
            : snapshot.fileName}
      </p>
      <p className="scenery-control__hint">
        {preview
          ? "请在桌面版中选择本地图片。"
          : "可多选最多 12 张静态 PNG / JPEG，合计不超过 64 MiB。替换整个场景集，图片不上传。"}
      </p>
      <div className="scenery-control__actions">
        <button type="button" onClick={onChoose}>
          {busy ? "处理中…" : "选择图片"}
        </button>
        <button
          type="button"
          disabled={snapshot.state === "empty" && error === null}
          onClick={onClear}
        >
          清除背景
        </button>
      </div>
      {snapshot.state !== "empty" && snapshot.collection !== undefined && (
        <div className="scenery-control__actions">
          <button type="button" disabled={!canStep} onClick={onPrevious}>上一张背景</button>
          <span aria-live="polite">{snapshot.collection.index + 1} / {snapshot.collection.count}</span>
          <button type="button" disabled={!canStep} onClick={onNext}>下一张背景</button>
        </div>
      )}
      {onAutoRotateChange !== undefined && (
        <label>
          <input type="checkbox" checked={autoRotate} disabled={rotationBusy}
            onChange={(event) => onAutoRotateChange(event.currentTarget.checked)} />
          自动轮换背景
          <span className="scenery-control__hint">约每 11 秒切换；窗口不在前台或启用减少动态效果时暂停。图片失效时暂停，可手动切换恢复。</span>
        </label>
      )}
      {!preview && issue !== null && (
        <p className="preferences-control__error" role="status">
          {errorCopy[issue]}
        </p>
      )}
    </fieldset>
  );
};
