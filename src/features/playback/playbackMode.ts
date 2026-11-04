import type { PlaybackMode, PlaybackSnapshot } from "../../contracts/playback";

export interface PlaybackModeOption {
  readonly mode: PlaybackMode;
  readonly label: string;
  readonly hint: string;
}

/** The three user-facing modes. Every one of them keeps playing after a track ends. */
export const playbackModeOptions: ReadonlyArray<PlaybackModeOption> = [
  { mode: "shuffle", label: "随机播放", hint: "每首一轮不重复，播完重新洗牌" },
  { mode: "sequential", label: "列表循环", hint: "按队列顺序播放，末尾回到第一首" },
  { mode: "one", label: "单曲播放", hint: "重复播放当前曲目" },
];

/** Legacy `none` and any shuffle/repeat combination collapse into one of the three modes. */
export const playbackModeOf = (snapshot: PlaybackSnapshot | null): PlaybackMode => {
  if (snapshot === null) return "sequential";
  if (snapshot.repeatMode === "one") return "one";
  return snapshot.shuffle ? "shuffle" : "sequential";
};

export const playbackModeLabel = (mode: PlaybackMode): string =>
  playbackModeOptions.find((option) => option.mode === mode)?.label ?? "列表循环";
