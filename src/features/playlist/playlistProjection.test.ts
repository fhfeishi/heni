import { describe, expect, it } from "vitest";

import type { LibraryItem, LibraryPlaylist } from "../../contracts/library";
import {
  projectPlaylistCandidates,
  projectPlaylistMembers,
} from "./playlistProjection";

const items: ReadonlyArray<LibraryItem> = [
  {
    id: "one",
    path: "C:\\Music\\One.flac",
    title: "晨光",
    kind: "audio",
    durationMs: 1,
    available: true,
    metadataStatus: "indexed",
    fastMetadata: null,
  },
  {
    id: "two",
    path: "D:\\Archive\\Two.mp3",
    title: "Night Drive",
    kind: "audio",
    durationMs: 2,
    available: false,
    metadataStatus: "failed",
    fastMetadata: null,
  },
];

const playlist: LibraryPlaylist = {
  id: "playlist",
  name: "通勤",
  description: "",
  itemIds: ["missing", "one"],
};

describe("playlistProjection", () => {
  it("keeps playlist order and unresolved membership references", () => {
    const rows = projectPlaylistMembers(playlist, items, "");

    expect(rows.map(({ mediaId, playlistIndex }) => [mediaId, playlistIndex])).toEqual([
      ["missing", 0],
      ["one", 1],
    ]);
    expect(rows[0]?.item).toBeNull();
  });

  it("filters members and add candidates without changing ownership", () => {
    expect(projectPlaylistMembers(playlist, items, "晨光")[0]?.mediaId).toBe("one");
    expect(projectPlaylistCandidates(playlist, items, "archive")).toEqual([items[1]]);
    expect(playlist.itemIds).toEqual(["missing", "one"]);
  });
});
