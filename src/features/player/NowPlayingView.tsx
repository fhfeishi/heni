import type { LibraryItem } from "../../contracts/library";
import type {
  PlaybackItem,
  PlaybackStatus,
} from "../../contracts/playback";

export interface NowPlayingViewProps {
  currentItem: PlaybackItem | null;
  currentLibraryItem: LibraryItem | null;
  nextItem: PlaybackItem | null;
  status: PlaybackStatus | null;
  picking: boolean;
  busy: boolean;
  loadingDetails: boolean;
  onChooseFiles(): void;
  onChooseDirectory(): void;
  onOpenLibrary(): void;
  onInspectDetails(): void;
}

const statusCopy: Readonly<Record<PlaybackStatus, string>> = {
  idle: "等待选择",
  loading: "正在载入",
  playing: "正在播放",
  paused: "已暂停",
  stopped: "已停止",
  completed: "播放完成",
  failed: "播放失败",
};

const metadataSummary = (item: LibraryItem | null): ReadonlyArray<string> => {
  const metadata = item?.fastMetadata;
  if (metadata === null || metadata === undefined) {
    return [];
  }
  return [
    metadata.codecName?.toUpperCase() ?? null,
    metadata.sampleRateHz === null
      ? null
      : `${metadata.sampleRateHz.toLocaleString()} Hz`,
    metadata.channels === null ? null : `${metadata.channels} 声道`,
    metadata.bitsPerSample === null ? null : `${metadata.bitsPerSample} bit`,
  ].filter((value): value is string => value !== null);
};

export const NowPlayingView = ({
  currentItem,
  currentLibraryItem,
  nextItem,
  status,
  picking,
  busy,
  loadingDetails,
  onChooseFiles,
  onChooseDirectory,
  onOpenLibrary,
  onInspectDetails,
}: NowPlayingViewProps) => {
  const metadata = metadataSummary(currentLibraryItem);

  return (
    <section className="now-playing-view" data-empty={currentItem === null} aria-labelledby="now-playing-title">
      <div className="view-heading">
        <div>
          <p className="section-label">聆听时刻</p>
          <h2 id="now-playing-title">
            {currentItem === null ? "开始聆听" : "正在播放"}
          </h2>
        </div>
        {currentItem !== null && (
          <div className="view-heading__actions">
            {currentLibraryItem !== null && (
              <button
                type="button"
                className="quiet-action"
                disabled={loadingDetails}
                onClick={onInspectDetails}
              >
                {loadingDetails ? "正在读取详情…" : "媒体详情"}
              </button>
            )}
            <button
              type="button"
              className="quiet-action"
              onClick={onOpenLibrary}
            >
              在曲库中查看
            </button>
          </div>
        )}
      </div>

      <div className="listening-console">
        <div className="artwork-fallback" aria-hidden="true">
          <div className="vinyl-ring" />
        </div>

        <div className="listening-copy">
          <span className="playback-state">
            {status === null ? "正在准备播放" : statusCopy[status]}
          </span>
          <h3>{currentItem?.title ?? "从一首歌开始"}</h3>
          <p>
            {currentItem === null
              ? "选择音乐或视频，或导入一个文件夹。媒体始终保留在本机。"
              : "本地音乐 · 安心聆听"}
          </p>

          {metadata.length > 0 && (
            <details className="stage-audio-details">
              <summary>音频信息</summary>
              <div className="metadata-chips" aria-label="音频快速信息">
                {metadata.map((value) => (
                  <span key={value}>{value}</span>
                ))}
              </div>
            </details>
          )}

          {currentItem === null && (
            <div className="empty-actions">
              <button
                type="button"
                className="primary-action"
                disabled={busy}
                onClick={onChooseFiles}
              >
                {picking ? "正在打开…" : "选择媒体文件"}
              </button>
              <button
                type="button"
                className="quiet-action"
                disabled={busy}
                onClick={onChooseDirectory}
              >
                导入音乐文件夹
              </button>
            </div>
          )}
        </div>

        <aside className="next-track-card" aria-label="队列下一项">
          <span>队列下一项</span>
          <strong>{nextItem?.title ?? "队列中没有下一首"}</strong>
          <p>{nextItem === null ? "可从曲库加入音乐" : "继续聆听，无需离开舞台"}</p>
        </aside>
      </div>
    </section>
  );
};
