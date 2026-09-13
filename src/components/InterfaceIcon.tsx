const paths = {
  add: "M12 5v14M5 12h14",
  edit: "m15 4 5 5M4 20l5-1L20 8a2 2 0 0 0-5-5L4 14Z",
  subtract: "M7 12h10M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z",
  play: "m9 5 11 7-11 7Z",
  locate: "M12 2v4m0 12v4M2 12h4m12 0h4M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10Z",
  remove: "M5 7h14M9 7V4h6v3M7 7l1 13h8l1-13M10 10v7m4-7v7",
  image: "M4 4h16v16H4Zm0 12 5-5 4 4 3-3 4 4M15 8h.01",
  minimize: "M5 12h14",
  maximize: "M5 5h14v14H5Z",
  restore: "M8 5h11v11M5 8h11v11H5Z",
  songs: "M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01",
  stage: "M4 5h16v12H4Zm5 16h6m-3-4v4M10 8l5 3-5 3Z",
  reset: "M4 10a8 8 0 1 1 1 8M4 4v6h6",
  pin: "M8 3h8l-1 6 4 4v2H5v-2l4-4Zm4 12v7",
  settings: "M4 7h16M4 17h16M8 4v6M16 14v6",
  mini: "M4 5h16v14H4Zm8 8h8v6h-8Z",
  expand: "M8 4H4v4m12-4h4v4M4 16v4h4m12-4v4h-4",
  close: "m6 6 12 12M18 6 6 18",
  check: "m5 12 4 4L19 6",
} as const;

export const InterfaceIcon = ({ name }: { name: keyof typeof paths }) => (
  <svg className="interface-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
    <path d={paths[name]} />
  </svg>
);
