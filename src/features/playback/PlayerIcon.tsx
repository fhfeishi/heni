const paths = {
  play: "m9 5 11 7-11 7Z",
  pause: "M8 5v14M16 5v14",
  previous: "M5 5v14m14-14L8 12l11 7Z",
  next: "M19 5v14M5 5l11 7-11 7Z",
  stop: "M6 6h12v12H6Z",
  queue: "M4 6h16M4 12h10M4 18h10m4-6 4 3-4 3Z",
  volume: "M4 9h4l5-4v14l-5-4H4Zm12-1a6 6 0 0 1 0 8m3-11a10 10 0 0 1 0 14",
  muted: "M4 9h4l5-4v14l-5-4H4Zm13 0 5 6m0-6-5 6",
  repeat: "m17 2 4 4-4 4M3 11V9a3 3 0 0 1 3-3h15M7 22l-4-4 4-4m14-1v2a3 3 0 0 1-3 3H3",
  shuffle: "M3 6h3c4 0 8 12 12 12h3m-4-4 4 4-4 4M3 18h3c1 0 3-2 4-4m4-4c1-2 3-4 4-4h3m-4-4 4 4-4 4",
} as const;

export const PlayerIcon = ({ name }: { name: keyof typeof paths }) => (
  <svg className="player-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7"
    strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
    <path d={paths[name]} />
  </svg>
);
