import { useEffect, useRef, useState, type CSSProperties } from "react";
import { PlayerIcon } from "./PlayerIcon";
import type {
  PlaybackCommand,
  PlaybackSnapshot,
} from "../../contracts/playback";

interface PlaybackVolumeProps {
  snapshot: PlaybackSnapshot | null;
  busy: boolean;
  onDispatch(command: PlaybackCommand): Promise<boolean>;
}

export const PlaybackVolume = ({
  snapshot,
  busy,
  onDispatch,
}: PlaybackVolumeProps) => {
  const [draft, setDraft] = useState<Readonly<{
    volume: number;
    baseVolume: number;
    baseMuted: boolean;
  }> | null>(null);
  const [pending, setPending] = useState(false);
  const submitting = useRef(false);
  const lifecycle = useRef(0);
  useEffect(
    () => () => {
      lifecycle.current += 1;
    },
    [],
  );

  const activeDraft =
    draft !== null &&
    draft.baseVolume === snapshot?.volume &&
    draft.baseMuted === snapshot.muted
      ? draft
      : null;
  // Invalidate permanently: an external value may later return to the gesture's starting value.
  if (draft !== null && activeDraft === null) setDraft(null);
  const volume = activeDraft?.volume ?? snapshot?.volume ?? 100;
  const muteLabel = snapshot?.muted === true ? "恢复声音" : "静音";
  const disabled = snapshot === null || (busy && !pending);

  const stage = (value: number) => {
    if (snapshot === null || busy || submitting.current) return;
    setDraft({
      volume: Math.round(Math.max(0, Math.min(value, 100))),
      baseVolume: snapshot.volume,
      baseMuted: snapshot.muted,
    });
  };
  const cancel = () => {
    if (!submitting.current) setDraft(null);
  };
  const submit = async (command: PlaybackCommand) => {
    if (snapshot === null || busy || submitting.current) return;
    submitting.current = true;
    setPending(true);
    const epoch = lifecycle.current;
    try {
      await onDispatch(command);
    } finally {
      submitting.current = false;
      if (lifecycle.current === epoch) {
        setPending(false);
        setDraft(null);
      }
    }
  };
  const commit = () => {
    if (activeDraft !== null)
      void submit({ type: "set-volume", volume: activeDraft.volume });
  };

  return (
    <div className="playback-volume" data-muted={snapshot?.muted === true}
      style={{ "--volume-position": `${volume}%` } as CSSProperties}>
      <button
        type="button"
        className="utility-button"
        aria-label={muteLabel}
        title={muteLabel}
        aria-pressed={snapshot?.muted === true}
        aria-disabled={pending || undefined}
        aria-busy={pending || undefined}
        disabled={disabled}
        onClick={() =>
          void submit({ type: "set-muted", muted: !(snapshot?.muted ?? false) })
        }
      >
        <PlayerIcon name={snapshot?.muted === true ? "muted" : "volume"} />
      </button>
      <input
        aria-label="音量"
        aria-valuetext={`${volume}%`}
        title={`音量 ${volume}% · 松开后应用`}
        aria-disabled={pending || undefined}
        aria-busy={pending || undefined}
        type="range"
        min="0"
        max="100"
        step="1"
        value={volume}
        disabled={disabled}
        onChange={(event) => stage(Number(event.currentTarget.value))}
        onPointerDown={(event) => {
          if (busy || submitting.current) {
            event.preventDefault();
            return;
          }
          event.currentTarget.setPointerCapture(event.pointerId);
        }}
        onPointerUp={commit}
        onPointerCancel={cancel}
        onLostPointerCapture={cancel}
        onBlur={cancel}
        onKeyDown={(event) => {
          if (event.key === "Escape") {
            event.preventDefault();
            cancel();
            return;
          }
          const target =
            event.key === "Home"
              ? 0
              : event.key === "End"
                ? 100
                : event.key === "ArrowRight" || event.key === "ArrowUp"
                  ? volume + 1
                  : event.key === "ArrowLeft" || event.key === "ArrowDown"
                    ? volume - 1
                    : event.key === "PageUp"
                      ? volume + 10
                      : event.key === "PageDown"
                        ? volume - 10
                        : null;
          if (target !== null) {
            event.preventDefault();
            stage(target);
          }
        }}
        onKeyUp={(event) => {
          if (
            [
              "Home",
              "End",
              "ArrowLeft",
              "ArrowRight",
              "ArrowUp",
              "ArrowDown",
              "PageUp",
              "PageDown",
            ].includes(event.key)
          )
            commit();
        }}
      />
      <span className="playback-volume__value" aria-hidden="true">
        {snapshot?.muted === true ? "已静音" : `${volume}%`}
      </span>
    </div>
  );
};
