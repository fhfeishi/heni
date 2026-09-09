export const appViews = [
  "now-playing",
  "library",
  "playlists",
  "queue",
] as const;

export type AppView = (typeof appViews)[number];

export const appViewLabels: Readonly<Record<AppView, string>> = {
  "now-playing": "正在播放",
  library: "曲库",
  playlists: "歌单",
  queue: "播放队列",
};
