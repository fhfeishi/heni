import { useEffect, useRef, useState } from "react";
import type { PlaybackCommand, PlaybackSnapshot } from "../../contracts/playback";
import { PlayerIcon } from "./PlayerIcon";
import { playbackModeLabel, playbackModeOf, playbackModeOptions } from "./playbackMode";

export const PlaybackModeControl = ({ snapshot, busy, onDispatch }: {
  snapshot: PlaybackSnapshot | null;
  busy: boolean;
  onDispatch(command: PlaybackCommand): Promise<boolean>;
}) => {
  const root = useRef<HTMLDetailsElement>(null);
  const submitting = useRef(false);
  const lifecycle = useRef(0);
  const [pending, setPending] = useState(false);
  useEffect(() => {
    lifecycle.current += 1;
    const dismiss = (event: PointerEvent) => {
      if (event.target instanceof Node && root.current !== null && !root.current.contains(event.target)) root.current.open = false;
    };
    document.addEventListener("pointerdown", dismiss);
    return () => { lifecycle.current += 1; document.removeEventListener("pointerdown", dismiss); };
  }, []);
  const send = async (command: PlaybackCommand) => {
    if (busy || snapshot === null || submitting.current) return;
    submitting.current = true;
    setPending(true);
    const epoch = lifecycle.current;
    try { await onDispatch(command); }
    finally { submitting.current = false; if (epoch === lifecycle.current) setPending(false); }
  };
  const mode = playbackModeOf(snapshot);
  const label = playbackModeLabel(mode);
  const icon = mode === "shuffle" ? "shuffle" : mode === "one" ? "repeatOne" : "repeat";
  return (
    <details className="playback-mode" ref={root} onKeyDown={(event) => {
      if (event.key === "Escape" && root.current !== null) {
        event.preventDefault(); root.current.open = false; root.current.querySelector("summary")?.focus();
      }
    }}>
      <summary title={label} aria-label={`播放模式：${label}`}><PlayerIcon name={icon} /></summary>
      <fieldset className="playback-mode__panel" disabled={busy || pending || snapshot === null}>
        <legend>播放模式</legend>
        <p>播完自动续播，不会停在曲尾</p>
        <div>
          {playbackModeOptions.map((option) => <button type="button" key={option.mode} title={option.hint}
            aria-pressed={mode === option.mode}
            onClick={() => void send({ type: "set-playback-mode", mode: option.mode })}>{option.label}</button>)}
        </div>
      </fieldset>
    </details>
  );
};
