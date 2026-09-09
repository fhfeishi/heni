import { useEffect, useMemo, useRef, useState } from "react";

import type {
  PlaybackCommand,
  PlaybackSnapshot,
} from "../../contracts/playback";
import { projectQueueRows } from "./queueProjection";

export interface QueueViewProps {
  snapshot: PlaybackSnapshot | null;
  busy: boolean;
  onDispatch(command: PlaybackCommand): void;
}

const repeatLabel: Readonly<Record<PlaybackSnapshot["repeatMode"], string>> = {
  none: "不循环",
  all: "列表循环",
  one: "单曲循环",
};

const nextRepeatMode = (
  current: PlaybackSnapshot["repeatMode"],
): PlaybackSnapshot["repeatMode"] => {
  if (current === "none") {
    return "all";
  }
  if (current === "all") {
    return "one";
  }
  return "none";
};

const snapshotKey = (snapshot: PlaybackSnapshot): string =>
  `${snapshot.generation}:${snapshot.sequence}`;

interface QueueDragState {
  fromIndex: number;
  snapshotKey: string;
}

export const QueueView = ({ snapshot, busy, onDispatch }: QueueViewProps) => {
  const [search, setSearch] = useState("");
  const [locateRequest, setLocateRequest] = useState(0);
  const [clearConfirmationKey, setClearConfirmationKey] = useState<
    string | null
  >(null);
  const [dragState, setDragState] = useState<QueueDragState | null>(null);
  const [dragTargetIndex, setDragTargetIndex] = useState<number | null>(null);
  const currentButtonRef = useRef<HTMLButtonElement>(null);
  const rows = useMemo(
    () =>
      projectQueueRows(
        snapshot?.queue ?? [],
        snapshot?.currentIndex ?? null,
        search,
      ),
    [search, snapshot?.currentIndex, snapshot?.queue],
  );
  const confirmationOpen =
    snapshot !== null && clearConfirmationKey === snapshotKey(snapshot);
  const reorderEnabled =
    snapshot !== null &&
    snapshot.queue.length > 1 &&
    search.trim() === "" &&
    !busy;

  useEffect(() => {
    if (locateRequest === 0) {
      return;
    }
    const button = currentButtonRef.current;
    button?.focus({ preventScroll: true });
    button?.scrollIntoView?.({ block: "center" });
  }, [locateRequest]);

  const locateCurrent = () => {
    setSearch("");
    setLocateRequest((request) => request + 1);
  };

  const dispatchReorder = (fromIndex: number, toIndex: number) => {
    if (fromIndex === toIndex) {
      return;
    }
    onDispatch({ type: "reorder-queue", fromIndex, toIndex });
  };

  const finishDrag = () => {
    setDragState(null);
    setDragTargetIndex(null);
  };

  return (
    <section className="queue-view" aria-labelledby="queue-title">
      <div className="view-heading">
        <div>
          <p className="section-label">接下来播放</p>
          <h2 id="queue-title">播放队列</h2>
        </div>
        <div className="queue-mode-actions" aria-label="播放模式">
          <button
            type="button"
            disabled={snapshot === null || busy}
            onClick={() =>
              snapshot === null
                ? undefined
                : onDispatch({
                    type: "set-repeat-mode",
                    repeatMode: nextRepeatMode(snapshot.repeatMode),
                  })
            }
          >
            {repeatLabel[snapshot?.repeatMode ?? "all"]}
          </button>
          <button
            type="button"
            className={snapshot?.shuffle === true ? "mode-active" : undefined}
            disabled={snapshot === null || busy}
            onClick={() =>
              onDispatch({
                type: "set-shuffle",
                shuffle: !(snapshot?.shuffle ?? false),
              })
            }
          >
            随机播放
          </button>
        </div>
      </div>

      {snapshot !== null && snapshot.queue.length > 0 && (
        <div className="queue-toolbar" aria-label="队列工具">
          <label>
            <span>搜索队列</span>
            <input
              type="search"
              value={search}
              placeholder="标题或路径"
              onChange={(event) => setSearch(event.currentTarget.value)}
            />
          </label>
          <span className="queue-count">
            {rows.length === snapshot.queue.length
              ? `${snapshot.queue.length} 项${snapshot.queue.length > 1 ? " · 可拖动" : ""}`
              : `${rows.length} / ${snapshot.queue.length} 项`}
          </span>
          <button
            type="button"
            disabled={snapshot.currentIndex === null}
            onClick={locateCurrent}
          >
            定位当前项
          </button>
          <button
            type="button"
            className="danger-button"
            disabled={busy}
            onClick={() => setClearConfirmationKey(snapshotKey(snapshot))}
          >
            清空队列
          </button>
        </div>
      )}

      {confirmationOpen && (
        <div className="queue-clear-confirmation" role="alert">
          <div>
            <strong>清空当前播放队列？</strong>
            <span>正在播放的媒体会停止；曲库和歌单不会被删除。</span>
          </div>
          <button
            type="button"
            onClick={() => setClearConfirmationKey(null)}
          >
            取消
          </button>
          <button
            type="button"
            className="danger-button"
            disabled={busy}
            onClick={() => {
              setClearConfirmationKey(null);
              onDispatch({
                type: "replace-queue",
                queue: [],
                currentIndex: null,
                autoplay: false,
              });
            }}
          >
            确认清空队列
          </button>
        </div>
      )}

      {snapshot === null || snapshot.queue.length === 0 ? (
        <div className="view-empty">
          <strong>播放队列还是空的</strong>
          <p>从曲库选择“播放”“下一首”或“加入队列”即可开始。</p>
        </div>
      ) : rows.length === 0 ? (
        <div className="view-empty">
          <strong>队列中没有匹配项</strong>
          <p>搜索不会改变实际播放队列。</p>
          <button type="button" onClick={locateCurrent}>
            清除搜索并定位当前项
          </button>
        </div>
      ) : (
        <>
          <p id="queue-reorder-help" className="visually-hidden">
            清除搜索后可拖放队列项，或使用每行的上移和下移按钮重排。
          </p>
          <ol
            className="queue-view-list"
            aria-label="活动播放队列"
            aria-describedby="queue-reorder-help"
          >
          {rows.map(({ item, queueIndex, isCurrent, isNext }) => (
            <li
              key={`${queueIndex}:${item.id}`}
              aria-label={`${item.title}${isCurrent ? "，当前播放" : isNext ? "，下一首" : ""}`}
              draggable={reorderEnabled}
              className={
                [
                  isCurrent ? "is-current" : isNext ? "is-next" : "",
                  dragState?.fromIndex === queueIndex ? "is-dragging" : "",
                  dragTargetIndex === queueIndex ? "is-drag-target" : "",
                ]
                  .filter((value) => value !== "")
                  .join(" ") || undefined
              }
              onDragStart={(event) => {
                if (!reorderEnabled || snapshot === null) {
                  event.preventDefault();
                  return;
                }
                event.dataTransfer.effectAllowed = "move";
                event.dataTransfer.setData("text/plain", String(queueIndex));
                setDragState({
                  fromIndex: queueIndex,
                  snapshotKey: snapshotKey(snapshot),
                });
              }}
              onDragOver={(event) => {
                if (
                  dragState !== null &&
                  dragState.fromIndex !== queueIndex &&
                  snapshot !== null &&
                  dragState.snapshotKey === snapshotKey(snapshot)
                ) {
                  event.preventDefault();
                  event.dataTransfer.dropEffect = "move";
                  setDragTargetIndex(queueIndex);
                }
              }}
              onDrop={(event) => {
                event.preventDefault();
                if (
                  dragState !== null &&
                  snapshot !== null &&
                  dragState.snapshotKey === snapshotKey(snapshot)
                ) {
                  dispatchReorder(dragState.fromIndex, queueIndex);
                }
                finishDrag();
              }}
              onDragEnd={finishDrag}
            >
              {reorderEnabled && (
                <span className="queue-row__drag" aria-hidden="true">
                  ⠿
                </span>
              )}
              <button
                ref={isCurrent ? currentButtonRef : undefined}
                type="button"
                className="queue-row__play"
                aria-label={`播放 ${item.title}`}
                aria-current={isCurrent ? "true" : undefined}
                disabled={busy}
                onClick={() =>
                  onDispatch({ type: "play-index", index: queueIndex })
                }
              >
                <span className="queue-row__index">
                  {isCurrent ? "▶" : String(queueIndex + 1).padStart(2, "0")}
                </span>
                <span className="queue-row__copy">
                  <span className="queue-row__title">
                    <strong>{item.title}</strong>
                    {isCurrent && <small>当前播放</small>}
                    {isNext && <small>下一首</small>}
                  </span>
                  <small>{item.path}</small>
                </span>
              </button>
              <div className="queue-row__actions">
                {reorderEnabled && (
                  <>
                    <button
                      type="button"
                      className="queue-row__move"
                      aria-label={`上移 ${item.title}`}
                      disabled={queueIndex === 0}
                      onClick={() => dispatchReorder(queueIndex, queueIndex - 1)}
                    >
                      ↑
                    </button>
                    <button
                      type="button"
                      className="queue-row__move"
                      aria-label={`下移 ${item.title}`}
                      disabled={queueIndex === snapshot.queue.length - 1}
                      onClick={() => dispatchReorder(queueIndex, queueIndex + 1)}
                    >
                      ↓
                    </button>
                  </>
                )}
                <button
                  type="button"
                  className="queue-row__remove"
                  aria-label={`从队列移除 ${item.title}`}
                  disabled={busy}
                  onClick={() =>
                    onDispatch({ type: "remove-index", index: queueIndex })
                  }
                >
                  移除
                </button>
              </div>
            </li>
          ))}
          </ol>
        </>
      )}
    </section>
  );
};
