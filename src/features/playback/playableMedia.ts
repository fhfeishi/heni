import type { LibraryItem } from "../../contracts/library";

/** Container eligibility only: actual video codec support is checked during playback. */
export const isPlayableMedia = (item: Pick<LibraryItem, "available" | "kind" | "path">): boolean =>
  item.available && (item.kind === "audio" || /\.(mp4|m4v|mov|webm)$/iu.test(item.path));
