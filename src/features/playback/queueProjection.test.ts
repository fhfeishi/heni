import { describe, expect, it } from "vitest";

import type { PlaybackItem } from "../../contracts/playback";
import { projectQueueRows } from "./queueProjection";

const queue: ReadonlyArray<PlaybackItem> = [
  {
    id: "one",
    path: "C:\\Music\\First.flac",
    title: "晨光",
    kind: "audio",
    durationMs: 60_000,
  },
  {
    id: "two",
    path: "D:\\Archive\\Second.mp3",
    title: "Night Drive",
    kind: "audio",
    durationMs: 70_000,
  },
  {
    id: "three",
    path: "C:\\Music\\Third.flac",
    title: "尾声",
    kind: "audio",
    durationMs: 80_000,
  },
];

describe("projectQueueRows", () => {
  it("filters by title or path while retaining authoritative queue indexes", () => {
    expect(projectQueueRows(queue, 0, "archive")).toEqual([
      {
        item: queue[1],
        queueIndex: 1,
        isCurrent: false,
        isNext: true,
      },
    ]);
    expect(projectQueueRows(queue, 1, "尾声")[0]?.queueIndex).toBe(2);
  });

  it("marks current and next rows without mutating the source queue", () => {
    const before = [...queue];
    const rows = projectQueueRows(queue, 1, "");

    expect(rows.map(({ isCurrent, isNext }) => [isCurrent, isNext])).toEqual([
      [false, false],
      [true, false],
      [false, true],
    ]);
    expect(queue).toEqual(before);
  });
});
