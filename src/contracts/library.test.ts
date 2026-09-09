import { describe, expect, it } from "vitest";

import { librarySnapshotSchema } from "./library";

describe("librarySnapshotSchema", () => {
  it("accepts a validated persisted media snapshot", () => {
    expect(
      librarySnapshotSchema.safeParse({
        schemaVersion: 1,
        items: [
          {
            id: "c:\\music\\one.flac",
            path: "C:\\Music\\One.flac",
            title: "One.flac",
            kind: "audio",
            durationMs: 60_000,
            available: true,
            metadataStatus: "indexed",
            fastMetadata: {
              codecName: "flac",
              sampleRateHz: 48_000,
              channels: 2,
              bitsPerSample: 24,
              fileSizeBytes: 2_048,
              estimatedBitRateBps: 1_411_200,
            },
          },
        ],
        playlists: [
          {
            id: "playlist-one",
            name: "通勤",
            description: "早晚路上",
            itemIds: ["c:\\music\\one.flac"],
          },
        ],
      }).success,
    ).toBe(true);
  });

  it("rejects an unknown storage schema version", () => {
    expect(
      librarySnapshotSchema.safeParse({
        schemaVersion: 2,
        items: [],
        playlists: [],
      }).success,
    ).toBe(false);
  });
});
