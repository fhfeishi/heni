import { useEffect, useRef, useState } from "react";
import type { PlaybackCommand, PlaybackSnapshot } from "../../contracts/playback";
import { PlayerIcon } from "./PlayerIcon";

const repeatOptions = [
  { value: "none", label: "播完停止" },
  { value: "all", label: "列表循环" },
  { value: "one", label: "单曲循环" },
] as const;

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
  const label = `${snapshot?.shuffle ? "随机" : "顺序"} · ${repeatOptions.find((option) => option.value === snapshot?.repeatMode)?.label ?? "播完停止"}`;
  return (
    <details className="playback-mode" ref={root} onKeyDown={(event) => {
      if (event.key === "Escape" && root.current !== null) {
        event.preventDefault(); root.current.open = false; root.current.querySelector("summary")?.focus();
      }
    }}>
      <summary title={label} aria-label={`播放模式：${label}`}><PlayerIcon name={snapshot?.shuffle ? "shuffle" : "repeat"} /></summary>
      <fieldset className="playback-mode__panel" disabled={busy || pending || snapshot === null}>
        <legend>播放模式</legend>
        <p>播放顺序</p>
        <div>
          {[false, true].map((shuffle) => <button type="button" key={String(shuffle)} aria-pressed={snapshot?.shuffle === shuffle}
            onClick={() => void send({ type: "set-shuffle", shuffle })}>{shuffle ? "随机播放" : "顺序播放"}</button>)}
        </div>
        <p>曲尾行为</p>
        <div>{repeatOptions.map((option) => <button type="button" key={option.value} aria-pressed={snapshot?.repeatMode === option.value}
          onClick={() => void send({ type: "set-repeat-mode", repeatMode: option.value })}>{option.label}</button>)}</div>
      </fieldset>
    </details>
  );
};
