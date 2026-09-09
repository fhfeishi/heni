import type { PlaybackCommand } from "../../contracts/playback";
import { PlayerIcon } from "./PlayerIcon";

export interface PlaybackTransportProps {
  disabled: boolean;
  isPlaying: boolean;
  onDispatch(command: PlaybackCommand): void;
}

export const PlaybackTransport = ({
  disabled,
  isPlaying,
  onDispatch,
}: PlaybackTransportProps) => (
  <div className="transport-buttons">
    <button
      type="button"
      aria-label="上一首"
      disabled={disabled}
      onClick={() => onDispatch({ type: "previous" })}
    >
      <PlayerIcon name="previous" />
    </button>
    <button
      type="button"
      className="transport-buttons__primary"
      aria-label={isPlaying ? "暂停" : "播放"}
      disabled={disabled}
      onClick={() => onDispatch({ type: isPlaying ? "pause" : "play" })}
    >
      <PlayerIcon name={isPlaying ? "pause" : "play"} />
    </button>
    <button
      type="button"
      aria-label="下一首"
      disabled={disabled}
      onClick={() => onDispatch({ type: "next" })}
    >
      <PlayerIcon name="next" />
    </button>
  </div>
);
