import { useEffect, useRef, useState, type CSSProperties } from "react";
import { PlayerIcon } from "./PlayerIcon";
import { VolumeGesture } from "./application/volumeGesture";
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
  const [draft, setDraft] = useState<{ volume: number; generation: number; sequence: number } | null>(null);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState(false);
  const gesture = useRef<VolumeGesture | null>(null);
  const submitting = useRef(false);
  const lifecycle = useRef(0);
  useEffect(() => {
    const epoch = lifecycle.current;
    const abandon = () => {
      const current = gesture.current;
      if (current === null || submitting.current) return;
      void current.finish(false).then(() => {
        if (lifecycle.current === epoch && gesture.current === current) {
          gesture.current = null;
          setDraft(null);
        }
      });
    };
    const visibility = () => { if (document.hidden) abandon(); };
    window.addEventListener("blur", abandon);
    document.addEventListener("visibilitychange", visibility);
    return () => {
      lifecycle.current += 1;
      void gesture.current?.finish(false);
      window.removeEventListener("blur", abandon);
      document.removeEventListener("visibilitychange", visibility);
    };
  }, []);
  useEffect(() => {
    const current = gesture.current;
    if (current === null || submitting.current) return;
    if (busy || current.generation !== snapshot?.generation || current.sequence !== snapshot.sequence) {
      const epoch = lifecycle.current;
      void current.finish(false).then(() => {
        if (lifecycle.current === epoch && gesture.current === current) {
          gesture.current = null;
          setDraft(null);
        }
      });
    }
  }, [busy, snapshot?.generation, snapshot?.sequence]);

  const activeDraft = draft !== null && (pending ||
    (draft.generation === snapshot?.generation && draft.sequence === snapshot.sequence)) ? draft : null;
  const volume = activeDraft?.volume ?? snapshot?.volume ?? 0;
  const muteLabel = snapshot?.muted === true ? "恢复声音" : "静音";
  const disabled = snapshot === null || (busy && !pending);

  const stage = (value: number) => {
    if (snapshot === null || busy || submitting.current || gesture.current?.closing) return;
    if (!Number.isFinite(value)) return;
    const target = Math.round(Math.max(0, Math.min(value, 100)));
    if (gesture.current === null) {
      const epoch = lifecycle.current;
      const current = new VolumeGesture(snapshot, onDispatch, () => {
        if (lifecycle.current === epoch && gesture.current === current) {
          gesture.current = null;
          setDraft(null);
          setError(true);
        }
      });
      gesture.current = current;
      setError(false);
    }
    gesture.current.stage(target);
    setDraft({ volume: target, generation: snapshot.generation, sequence: snapshot.sequence });
  };
  const cancel = () => {
    const current = gesture.current;
    if (submitting.current || current === null) return;
    const epoch = lifecycle.current;
    setDraft(null);
    void current.finish(false).then(() => {
      if (lifecycle.current === epoch && gesture.current === current) gesture.current = null;
    });
  };
  const finish = async (mute?: boolean) => {
    const current = gesture.current;
    if (snapshot === null || busy || submitting.current || (mute === undefined && (current === null || current.closing))) return;
    submitting.current = true;
    setPending(true);
    setError(false);
    const epoch = lifecycle.current;
    try {
      let ok: boolean;
      if (mute === undefined) {
        ok = current !== null && await current.finish(true);
      } else {
        if (current !== null) await current.finish(false);
        ok = await onDispatch({ type: "set-muted", muted: mute });
      }
      if (lifecycle.current === epoch) setError(!ok);
    } catch {
      if (lifecycle.current === epoch) setError(true);
    } finally {
      submitting.current = false;
      if (lifecycle.current === epoch) {
        gesture.current = null;
        setPending(false);
        setDraft(null);
      }
    }
  };
  const commit = () => { void finish(); };

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
          void finish(!(snapshot?.muted ?? false))
        }
      >
        <PlayerIcon name={snapshot?.muted === true ? "muted" : "volume"} />
      </button>
      <input
        aria-label="音量"
        aria-valuetext={`${volume}%`}
        title={`音量 ${volume}% · 拖动试听，松开保存`}
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
      {error && <span className="playback-volume__error" role="status">音量调整未完成，请重试</span>}
      <span className="playback-volume__value" aria-hidden="true">
        {snapshot?.muted === true ? "已静音" : `${volume}%`}
      </span>
    </div>
  );
};
