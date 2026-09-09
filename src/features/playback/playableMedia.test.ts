import { describe, expect, it } from "vitest";
import { isPlayableMedia } from "./playableMedia";

describe("isPlayableMedia", () => {
  it("shares video eligibility across library and playlist without promising codec support", () => {
    for (const extension of ["MP4", "m4v", "mov", "webm"]) {
      expect(isPlayableMedia({ path: `C:/Media/movie.${extension}`, kind: "video", available: true })).toBe(true);
    }
    expect(isPlayableMedia({ path: "C:/Media/movie.mkv", kind: "video", available: true })).toBe(false);
    expect(isPlayableMedia({ path: "C:/Media/movie.mp4", kind: "video", available: false })).toBe(false);
    expect(isPlayableMedia({ path: "C:/Media/song.flac", kind: "audio", available: true })).toBe(true);
  });
});
