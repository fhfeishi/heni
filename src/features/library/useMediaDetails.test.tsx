import { act, renderHook } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import type {
  LibraryPort,
  MediaDetails,
} from "../../contracts/library";
import { ok, type Result } from "../../contracts/result";
import { useMediaDetails } from "./useMediaDetails";

const details = (mediaId: string): MediaDetails => ({
  mediaId,
  sourcePath: `C:\\Music\\${mediaId}.flac`,
  provider: "ffprobe",
  formatName: "flac",
  formatLongName: "raw FLAC",
  durationMs: 1_000,
  sizeBytes: 8_192,
  bitRateBps: 65_536,
  streams: [],
  chapters: [],
  tags: {},
});

const portWith = (
  readMediaDetails: LibraryPort["readMediaDetails"],
): LibraryPort => ({
  readMediaDetails,
  readSnapshot: async () =>
    ok({ schemaVersion: 1, items: [], playlists: [] }),
  readLegacyImportStatus: async () => ok({ state: "not-found" }),
  importLegacy: async () =>
    ok({
      snapshot: { schemaVersion: 1, items: [], playlists: [] },
      importedMedia: 0,
      importedPlaylists: 0,
      backupPath: null,
      alreadyImported: true,
    }),
  createPlaylist: async () =>
    ok({ schemaVersion: 1, items: [], playlists: [] }),
  updatePlaylist: async () =>
    ok({ schemaVersion: 1, items: [], playlists: [] }),
  deletePlaylist: async () =>
    ok({ schemaVersion: 1, items: [], playlists: [] }),
  addPlaylistItems: async () =>
    ok({ schemaVersion: 1, items: [], playlists: [] }),
  removePlaylistItems: async () =>
    ok({ schemaVersion: 1, items: [], playlists: [] }),
  importFiles: async () =>
    ok({ schemaVersion: 1, items: [], playlists: [] }),
  relocateMedia: async () =>
    ok({ schemaVersion: 1, items: [], playlists: [] }),
  scanDirectory: async () =>
    ok({ schemaVersion: 1, items: [], playlists: [] }),
  cancelScan: async () => ok(false),
});

describe("useMediaDetails", () => {
  it("projects a validated on-demand detail result", async () => {
    const { result } = renderHook(() =>
      useMediaDetails(portWith(async (mediaId) => ok(details(mediaId)))),
    );

    await act(async () => {
      await result.current.inspect("media-one");
    });

    expect(result.current.details?.mediaId).toBe("media-one");
    expect(result.current.loadingMediaId).toBeNull();
  });

  it("does not let a slow earlier probe replace the latest selection", async () => {
    let finishFirst: (
      value: Result<MediaDetails, never>,
    ) => void = () => undefined;
    const port = portWith(
      (mediaId) =>
        mediaId === "first"
          ? new Promise((resolve) => {
              finishFirst = resolve;
            })
          : Promise.resolve(ok(details(mediaId))),
    );
    const { result } = renderHook(() => useMediaDetails(port));

    let first: Promise<boolean> = Promise.resolve(false);
    await act(async () => {
      first = result.current.inspect("first");
      await result.current.inspect("second");
    });
    await act(async () => {
      finishFirst(ok(details("first")));
      await first;
    });

    expect(result.current.details?.mediaId).toBe("second");
  });
});
