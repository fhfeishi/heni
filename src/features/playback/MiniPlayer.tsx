import type {
  PlaybackCommand,
  PlaybackItem,
  PlaybackSnapshot,
} from "../../contracts/playback";
import { PlaybackProgress } from "./PlaybackProgress";
import { PlaybackTransport } from "./PlaybackTransport";
import { PlayerIcon } from "./PlayerIcon";
import type { PlaybackClockSample } from "./application/playbackClock";

export interface MiniPlayerProps {
  snapshot: PlaybackSnapshot | null;
  clockSample: PlaybackClockSample | null;
  currentItem: PlaybackItem | null;
  busy: boolean;
  onDispatch(command: PlaybackCommand): Promise<boolean>;
  onOpenQueue(): void;
}

export const MiniPlayer = ({
  snapshot,
  clockSample,
  currentItem,
  busy,
  onDispatch,
  onOpenQueue,
}: MiniPlayerProps) => {
  const disabled = busy || snapshot === null || currentItem === null;
  const isPlaying = snapshot?.status === "playing";

  return (
    <section className="mini-player" aria-label="迷你播放器">
      <div className="mini-player__track">
        <span className="mini-artwork mini-artwork--large" aria-hidden="true" />
        <div>
          <span>本地音乐</span>
          <strong>{currentItem?.title ?? "尚未播放"}</strong>
          <small>{currentItem?.path ?? "返回主窗口选择本地音乐"}</small>
        </div>
      </div>

      <div className="mini-player__controls">
        <PlaybackTransport
          disabled={disabled}
          isPlaying={isPlaying}
          onDispatch={onDispatch}
        />
        <PlaybackProgress
          snapshot={snapshot}
          clockSample={clockSample}
          currentItem={currentItem}
          busy={busy}
          onDispatch={onDispatch}
        />
      </div>

      <div className="mini-player__utilities">
        <button type="button" className="utility-button" onClick={onOpenQueue}
          aria-label={`队列 ${snapshot?.queue.length ?? 0}`} title={`查看播放队列 · ${snapshot?.queue.length ?? 0} 首`}>
          <PlayerIcon name="queue" />
        </button>
        <button
          type="button"
          className="utility-button"
          aria-label={snapshot?.muted === true ? "恢复声音" : "静音"}
          title={snapshot?.muted === true ? "恢复声音" : "静音"}
          aria-pressed={snapshot?.muted === true}
          disabled={snapshot === null || busy}
          onClick={() =>
            onDispatch({
              type: "set-muted",
              muted: !(snapshot?.muted ?? false),
            })
          }
        >
          <PlayerIcon name={snapshot?.muted === true ? "muted" : "volume"} />
        </button>
      </div>
    </section>
  );
};
