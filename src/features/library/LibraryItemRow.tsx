import { useId, useState } from "react";
import { isPlayableMedia } from "../playback/playableMedia";

import type { LibraryItem } from "../../contracts/library";

export interface LibraryItemRowProps {
  item: LibraryItem;
  busy: boolean;
  loadingDetails: boolean;
  relocating: boolean;
  revealing: boolean;
  onInspect(): void;
  onPlay(): void;
  onPlayNext(): void;
  onEnqueue(): void;
  onRelocate(): void;
  onReveal(): void;
}

const metadataSummary = (item: LibraryItem): string => {
  if (item.fastMetadata === null) {
    return item.metadataStatus === "failed"
      ? "暂未读取文件信息 · 可查看详情"
      : "文件信息待补充";
  }
  return (
    [
      item.fastMetadata.codecName?.toUpperCase(),
      item.fastMetadata.sampleRateHz === null
        ? null
        : `${item.fastMetadata.sampleRateHz.toLocaleString()} Hz`,
      item.fastMetadata.channels === null
        ? null
        : `${item.fastMetadata.channels} 声道`,
      item.fastMetadata.estimatedBitRateBps === null
        ? null
        : `约 ${Math.round(item.fastMetadata.estimatedBitRateBps / 1_000)} kbps`,
    ]
      .filter((value): value is string => typeof value === "string")
      .join(" · ") || "基础信息已读取"
  );
};

export const LibraryItemRow = ({
  item,
  busy,
  loadingDetails,
  relocating,
  revealing,
  onInspect,
  onPlay,
  onPlayNext,
  onEnqueue,
  onRelocate,
  onReveal,
}: LibraryItemRowProps) => {
  const [actionsOpen, setActionsOpen] = useState(false);
  const actionsId = useId();
  const playable = isPlayableMedia(item);

  return (
    <li className={item.available ? undefined : "library-item--missing"}>
      <div className="library-item__copy">
        <div className="library-item__title">
          <strong title={item.title}>{item.title}</strong>
          <span className="media-kind-badge">
            {item.kind === "audio" ? "音频" : "视频"}
          </span>
          {!item.available && <span className="missing-badge">文件缺失</span>}
        </div>
        <span className="library-item-metadata">
          {item.available
            ? metadataSummary(item)
            : "原曲库与歌单引用已保留 · 等待重新定位"}
        </span>
      </div>

      <div className="library-actions">
        <button
          type="button"
          className="library-play-action"
          aria-label={
            item.available ? `播放 ${item.title}` : `重新定位 ${item.title}`
          }
          disabled={busy || (item.available && !playable)}
          onClick={item.available ? onPlay : onRelocate}
        >
          {item.available ? "播放" : relocating ? "选择中" : "重新定位"}
        </button>
        <button
          type="button"
          aria-label={`更多操作 ${item.title}`}
          aria-expanded={actionsOpen}
          aria-controls={actionsId}
          onClick={() => setActionsOpen((open) => !open)}
        >
          更多
        </button>
      </div>

      {actionsOpen && (
        <div
          id={actionsId}
          className="library-secondary-actions"
          role="group"
          aria-label={`${item.title} 的次级操作`}
        >
          <p className="library-item-path" aria-label="文件位置">
            {item.path}
          </p>
          <div className="library-secondary-actions__buttons">
            <button
              type="button"
              aria-label={`查看 ${item.title} 的媒体详情`}
              disabled={busy || !item.available || loadingDetails}
              onClick={onInspect}
            >
              {loadingDetails ? "读取中" : "媒体详情"}
            </button>
            <button
              type="button"
              aria-label={`下一首播放 ${item.title}`}
              disabled={busy || !playable}
              onClick={onPlayNext}
            >
              下一首播放
            </button>
            <button
              type="button"
              aria-label={`加入队列 ${item.title}`}
              disabled={busy || !playable}
              onClick={onEnqueue}
            >
              加入队列
            </button>
            <button
              type="button"
              aria-label={`在资源管理器中显示 ${item.title}`}
              disabled={busy || !item.available || revealing}
              onClick={onReveal}
            >
              {revealing ? "正在定位" : "在资源管理器中显示"}
            </button>
          </div>
        </div>
      )}
    </li>
  );
};
