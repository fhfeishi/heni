import { describe, expect, it } from "vitest";

import type { LibraryItem } from "../../contracts/library";
import { projectLibraryItems } from "./libraryProjection";

const itemAt = (index: number): LibraryItem => ({
  id: `media-${String(index).padStart(5, "0")}`,
  path: `C:\\音乐\\目录 ${index % 17}\\Track ${index}.flac`,
  title: `Track ${index}.flac`,
  kind: index % 5 === 0 ? "video" : "audio",
  durationMs: null,
  available: index % 7 !== 0,
  metadataStatus: "indexed",
  fastMetadata: {
    codecName: index % 10 === 0 ? "opus" : "flac",
    sampleRateHz: 48_000,
    channels: 2,
    bitsPerSample: 24,
    fileSizeBytes: 8_192,
    estimatedBitRateBps: 1_411_200,
  },
});

const defaults = {
  search: "",
  kind: "all" as const,
  availability: "all" as const,
  sort: "title-asc" as const,
};

describe("projectLibraryItems", () => {
  it("projects one item without mutating the input", () => {
    const items = [itemAt(1)];

    const result = projectLibraryItems(items, defaults);

    expect(result).toEqual(items);
    expect(result).not.toBe(items);
  });

  it("searches title, path and codec across 100 items", () => {
    const items = Array.from({ length: 100 }, (_, index) => itemAt(index));

    expect(
      projectLibraryItems(items, { ...defaults, search: "目录 3" }),
    ).toHaveLength(6);
    expect(
      projectLibraryItems(items, { ...defaults, search: "OPUS" }),
    ).toHaveLength(10);
    expect(
      projectLibraryItems(items, { ...defaults, search: "track 42" }).map(
        (item) => item.id,
      ),
    ).toEqual(["media-00042"]);
  });

  it("filters and sorts 5,000 items while preserving source order", () => {
    const items = Array.from({ length: 5_000 }, (_, index) => itemAt(index));
    const originalIds = items.map((item) => item.id);

    const result = projectLibraryItems(items, {
      ...defaults,
      kind: "video",
      availability: "missing",
      sort: "title-desc",
    });

    expect(result).toHaveLength(143);
    expect(result[0]?.title).toBe("Track 4970.flac");
    expect(items.map((item) => item.id)).toEqual(originalIds);
  });
});
