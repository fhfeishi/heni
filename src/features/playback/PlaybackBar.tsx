import type {
  PlaybackCommand,
  PlaybackItem,
  PlaybackSnapshot,
} from "../../contracts/playback";
import { PlaybackProgress } from "./PlaybackProgress";
import { PlaybackTransport } from "./PlaybackTransport";
import { PlaybackVolume } from "./PlaybackVolume";
import { PlaybackModeControl } from "./PlaybackModeControl";
import { PlayerIcon } from "./PlayerIcon";
import type { PlaybackClockSample } from "./application/playbackClock";

export interface PlaybackBarProps {
  snapshot: PlaybackSnapshot | null;
  clockSample: PlaybackClockSample | null;
  currentItem: PlaybackItem | null;
  busy: boolean;
  onDispatch(command: PlaybackCommand): Promise<boolean>;
  onOpenQueue(): void;
}

export const PlaybackBar = ({
  snapshot,
  clockSample,
  currentItem,
  busy,
  onDispatch,
  onOpenQueue,
}: PlaybackBarProps) => {
  const disabled = busy || snapshot === null || currentItem === null;
  const isPlaying = snapshot?.status === "playing";

  return (
    <footer className="playback-bar" aria-label="播放控制">
      <div className="playback-bar__track">
        <span className="mini-artwork" aria-hidden="true" />
        <div>
          <strong>{currentItem?.title ?? "尚未播放"}</strong>
          <span>
            {currentItem === null ? "选择本地音乐开始播放" : "本地媒体"}
          </span>
        </div>
      </div>

      <div className="playback-bar__center">
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

      <div className="playback-bar__utilities">
        <PlaybackModeControl snapshot={snapshot} busy={busy} onDispatch={onDispatch} />
        <button type="button" className="utility-button" aria-label={`队列 ${snapshot?.queue.length ?? 0}`} title="查看当前播放队列" onClick={onOpenQueue}>
          <PlayerIcon name="queue" />
        </button>
        <button
          type="button"
          className="utility-button"
          aria-label="停止"
          title="停止播放"
          disabled={disabled}
          onClick={() => onDispatch({ type: "stop" })}
        >
          <PlayerIcon name="stop" />
        </button>
        <PlaybackVolume
          snapshot={snapshot}
          busy={busy}
          onDispatch={onDispatch}
        />
      </div>
    </footer>
  );
};
