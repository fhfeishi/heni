import { useEffect, useRef, useState } from "react";

import type {
  PlaybackCommand,
  PlaybackItem,
  PlaybackSnapshot,
} from "../../contracts/playback";
import type { PlaybackClockSample } from "./application/playbackClock";
import { usePlaybackPosition } from "./usePlaybackPosition";

export interface PlaybackProgressProps {
  snapshot: PlaybackSnapshot | null;
  clockSample: PlaybackClockSample | null;
  currentItem: PlaybackItem | null;
  busy: boolean;
  onDispatch(command: PlaybackCommand): Promise<boolean>;
}

const formatTime = (milliseconds: number): string => {
  const seconds = Math.floor(milliseconds / 1_000);
  const minutes = Math.floor(seconds / 60);
  return `${minutes}:${String(seconds % 60).padStart(2, "0")}`;
};

export const PlaybackProgress = ({
  snapshot,
  clockSample,
  currentItem,
  busy,
  onDispatch,
}: PlaybackProgressProps) => {
  const [seekDraft, setSeekDraft] = useState<Readonly<{
    generation: number;
    sequence: number;
    mediaId: string;
    positionMs: number;
    phase: "dragging" | "pending";
  }> | null>(null);
  const pendingSeek = useRef(false);
  const lifecycle = useRef(0);
  useEffect(
    () => () => {
      lifecycle.current += 1;
    },
    [],
  );
  const durationMs = snapshot?.durationMs ?? 0;
  const activeSeekDraft =
    seekDraft !== null &&
    seekDraft.generation === snapshot?.generation &&
    seekDraft.sequence === snapshot.sequence &&
    seekDraft.mediaId === currentItem?.id
      ? seekDraft
      : null;
  const sampledPositionMs = usePlaybackPosition(
    clockSample,
    activeSeekDraft !== null,
  );
  const positionMs =
    activeSeekDraft?.positionMs ??
    (clockSample === null ? (snapshot?.positionMs ?? 0) : sampledPositionMs);
  const disabled = busy || snapshot === null || currentItem === null;
  const awaitingSeek = activeSeekDraft?.phase === "pending";

  const stageSeek = (position: number) => {
    if (disabled || pendingSeek.current || durationMs <= 0) return;
    setSeekDraft({
      generation: snapshot.generation,
      sequence: snapshot.sequence,
      mediaId: currentItem.id,
      positionMs: Math.round(Math.max(0, Math.min(position, durationMs))),
      phase: "dragging",
    });
  };

  const cancelSeek = () => {
    if (!pendingSeek.current) setSeekDraft(null);
  };

  const commitSeek = async () => {
    if (activeSeekDraft === null || disabled || pendingSeek.current) return;
    const startedAt = lifecycle.current;
    pendingSeek.current = true;
    setSeekDraft({ ...activeSeekDraft, phase: "pending" });
    try {
      await onDispatch({
        type: "seek",
        positionMs: activeSeekDraft.positionMs,
      });
    } finally {
      pendingSeek.current = false;
      if (lifecycle.current === startedAt) setSeekDraft(null);
    }
  };

  return (
    <div className="playback-progress">
      <span>{formatTime(positionMs)}</span>
      <input
        aria-label="播放进度"
        aria-disabled={awaitingSeek ? true : undefined}
        aria-busy={awaitingSeek ? true : undefined}
        aria-valuetext={`${formatTime(positionMs)} / ${durationMs === 0 ? "未知时长" : formatTime(durationMs)}`}
        type="range"
        min="0"
        max={Math.max(durationMs, 1)}
        step="1"
        value={Math.min(positionMs, Math.max(durationMs, 1))}
        disabled={
          snapshot === null ||
          currentItem === null ||
          durationMs === 0 ||
          (busy && !awaitingSeek)
        }
        onChange={(event) => stageSeek(Number(event.currentTarget.value))}
        onPointerDown={(event) => {
          if (disabled || awaitingSeek) {
            event.preventDefault();
            return;
          }
          event.currentTarget.setPointerCapture(event.pointerId);
        }}
        onPointerUp={() => void commitSeek()}
        onPointerCancel={cancelSeek}
        onLostPointerCapture={cancelSeek}
        onBlur={cancelSeek}
        onKeyDown={(event) => {
          if (event.key === "Escape") {
            event.preventDefault();
            cancelSeek();
            return;
          }
          const offset =
            event.key === "ArrowRight" || event.key === "ArrowUp"
              ? 1_000
              : event.key === "ArrowLeft" || event.key === "ArrowDown"
                ? -1_000
                : event.key === "PageUp"
                  ? 10_000
                  : event.key === "PageDown"
                    ? -10_000
                    : null;
          const target =
            event.key === "Home"
              ? 0
              : event.key === "End"
                ? durationMs
                : offset === null
                  ? null
                  : positionMs + offset;
          if (target !== null) {
            event.preventDefault();
            stageSeek(target);
          }
        }}
        onKeyUp={(event) => {
          if (
            [
              "ArrowLeft",
              "ArrowRight",
              "ArrowUp",
              "ArrowDown",
              "PageUp",
              "PageDown",
              "Home",
              "End",
            ].includes(event.key)
          ) {
            void commitSeek();
          }
        }}
      />
      <span>{durationMs === 0 ? "--:--" : formatTime(durationMs)}</span>
    </div>
  );
};
