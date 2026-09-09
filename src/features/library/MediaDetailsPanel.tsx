import { useEffect, useRef, type KeyboardEvent } from "react";

import type { MediaDetails } from "../../contracts/library";

export interface MediaDetailsPanelProps {
  details: MediaDetails;
  onClose(): void;
}

const formatDuration = (milliseconds: number | null): string => {
  if (milliseconds === null) {
    return "未知";
  }
  const totalSeconds = Math.round(milliseconds / 1_000);
  const minutes = Math.floor(totalSeconds / 60);
  return `${minutes}:${String(totalSeconds % 60).padStart(2, "0")}`;
};

const formatBytes = (bytes: number | null): string => {
  if (bytes === null) {
    return "未知";
  }
  return `${(bytes / 1024 / 1024).toFixed(2)} MiB`;
};

const formatBitRate = (bitsPerSecond: number | null): string =>
  bitsPerSecond === null
    ? "未知"
    : `${Math.round(bitsPerSecond / 1_000)} kbps`;

const streamKindLabels: Readonly<
  Record<MediaDetails["streams"][number]["kind"], string>
> = {
  audio: "音频",
  video: "视频",
  unknown: "其他",
};

const focusableSelector =
  "button:not([disabled]), a[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex='-1'])";

export const MediaDetailsPanel = ({
  details,
  onClose,
}: MediaDetailsPanelProps) => {
  const panelRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const previousFocus =
      document.activeElement instanceof HTMLElement
        ? document.activeElement
        : null;
    panelRef.current?.focus();

    return () => {
      if (previousFocus?.isConnected) {
        previousFocus.focus();
      }
    };
  }, []);

  const handleKeyDown = (event: KeyboardEvent<HTMLElement>) => {
    if (event.key === "Escape") {
      event.preventDefault();
      onClose();
      return;
    }
    if (event.key !== "Tab") {
      return;
    }

    const panel = panelRef.current;
    if (panel === null) {
      return;
    }
    const focusable = Array.from(
      panel.querySelectorAll<HTMLElement>(focusableSelector),
    );
    const first = focusable[0];
    const last = focusable.at(-1);
    if (first === undefined || last === undefined) {
      event.preventDefault();
      panel.focus();
      return;
    }
    if (
      event.shiftKey &&
      (document.activeElement === first || document.activeElement === panel)
    ) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  };

  return (
    <div
      className="media-details-layer"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) {
          onClose();
        }
      }}
    >
      <aside
        ref={panelRef}
        className="media-details"
        role="dialog"
        aria-modal="true"
        aria-labelledby="media-details-title"
        tabIndex={-1}
        onKeyDown={handleKeyDown}
      >
        <div className="media-details__heading">
          <div>
            <p className="section-label">文件信息</p>
            <h3 id="media-details-title">媒体详情</h3>
          </div>
          <button type="button" onClick={onClose}>
            关闭
          </button>
        </div>

        <dl className="media-details__summary">
          <div>
            <dt>容器</dt>
            <dd>{details.formatLongName ?? details.formatName ?? "未知"}</dd>
          </div>
          <div>
            <dt>时长</dt>
            <dd>{formatDuration(details.durationMs)}</dd>
          </div>
          <div>
            <dt>大小</dt>
            <dd>{formatBytes(details.sizeBytes)}</dd>
          </div>
          <div>
            <dt>总码率</dt>
            <dd>{formatBitRate(details.bitRateBps)}</dd>
          </div>
        </dl>

        <div className="media-details__streams">
          {details.streams.map((stream) => (
            <article key={`${stream.index}-${stream.kind}`}>
              <strong>
                流 {stream.index} · {streamKindLabels[stream.kind]}
              </strong>
              <span>
                {stream.codecLongName ?? stream.codecName ?? "未知编码"}
              </span>
              {stream.kind === "audio" && (
                <span>
                  {stream.sampleRateHz === null
                    ? "未知采样率"
                    : `${stream.sampleRateHz.toLocaleString()} Hz`}
                  {stream.channels === null
                    ? ""
                    : ` · ${stream.channels} 声道`}
                  {stream.bitRateBps === null
                    ? ""
                    : ` · ${formatBitRate(stream.bitRateBps)}`}
                </span>
              )}
              {stream.kind === "video" && (
                <span>
                  {stream.width === null || stream.height === null
                    ? "未知尺寸"
                    : `${stream.width} × ${stream.height}`}
                  {stream.frameRate === null
                    ? ""
                    : ` · ${stream.frameRate} fps`}
                </span>
              )}
            </article>
          ))}
        </div>

        {Object.keys(details.tags).length > 0 && (
          <dl className="media-details__tags">
            {Object.entries(details.tags).map(([key, value]) => (
              <div key={key}>
                <dt>{key}</dt>
                <dd>{value}</dd>
              </div>
            ))}
          </dl>
        )}
      </aside>
    </div>
  );
};
