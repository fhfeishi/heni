import { describe, expect, it, vi } from "vitest";

import { createLibraryPort } from "./libraryPort";

const emptySnapshot = { schemaVersion: 1, items: [], playlists: [] } as const;

describe("createLibraryPort", () => {
  it("maps playback items to the smaller Rust import DTO", async () => {
    const invoke = vi.fn().mockResolvedValue(emptySnapshot);
    const port = createLibraryPort(invoke);

    await port.importFiles([
      {
        id: "picker-id",
        path: "C:\\Music\\one.flac",
        title: "one.flac",
        kind: "audio",
        durationMs: null,
      },
    ]);

    expect(invoke).toHaveBeenCalledWith("library_import_files", {
      items: [
        {
          path: "C:\\Music\\one.flac",
          title: "one.flac",
          kind: "audio",
          durationMs: null,
        },
      ],
    });
  });

  it("maps relocation to one cohesive Rust request", async () => {
    const invoke = vi.fn().mockResolvedValue(emptySnapshot);
    const port = createLibraryPort(invoke);

    await port.relocateMedia({
      mediaId: "stable-media-id",
      newPath: "D:\\Recovered\\one.flac",
    });

    expect(invoke).toHaveBeenCalledWith("library_relocate_media", {
      request: {
        mediaId: "stable-media-id",
        newPath: "D:\\Recovered\\one.flac",
      },
    });
  });

  it("rejects an invalid Rust snapshot before it reaches React", async () => {
    const port = createLibraryPort(
      vi.fn().mockResolvedValue({ schemaVersion: 99, items: [] }),
    );

    await expect(port.readSnapshot()).resolves.toEqual({
      ok: false,
      error: {
        code: "invalid-contract",
        message: "Rust returned an unexpected library payload.",
      },
    });
  });

  it("validates legacy import status and outcome payloads", async () => {
    const invoke = vi.fn().mockImplementation(async (command: string) => {
      if (command === "library_legacy_import_status") {
        return { state: "ready", mediaCount: 3, playlistCount: 1 };
      }
      return {
        snapshot: emptySnapshot,
        importedMedia: 3,
        importedPlaylists: 1,
        backupPath: "C:\\AppData\\migration-backups\\library.json",
        alreadyImported: false,
      };
    });
    const port = createLibraryPort(invoke);

    await expect(port.readLegacyImportStatus()).resolves.toEqual({
      ok: true,
      value: { state: "ready", mediaCount: 3, playlistCount: 1 },
    });
    await expect(port.importLegacy()).resolves.toEqual({
      ok: true,
      value: {
        snapshot: emptySnapshot,
        importedMedia: 3,
        importedPlaylists: 1,
        backupPath: "C:\\AppData\\migration-backups\\library.json",
        alreadyImported: false,
      },
    });
  });

  it("validates on-demand ffprobe details behind the typed port", async () => {
    const payload = {
      mediaId: "media-one",
      sourcePath: "C:\\Music\\one.flac",
      provider: "ffprobe",
      formatName: "flac",
      formatLongName: "raw FLAC",
      durationMs: 1_000,
      sizeBytes: 8_192,
      bitRateBps: 65_536,
      streams: [],
      chapters: [],
      tags: { title: "One" },
    } as const;
    const invoke = vi.fn().mockResolvedValue(payload);
    const port = createLibraryPort(invoke);

    await expect(port.readMediaDetails("media-one")).resolves.toEqual({
      ok: true,
      value: payload,
    });
    expect(invoke).toHaveBeenCalledWith("library_media_details", {
      request: { mediaId: "media-one" },
    });
  });

  it("maps playlist mutations to cohesive request DTOs", async () => {
    const invoke = vi.fn().mockResolvedValue(emptySnapshot);
    const port = createLibraryPort(invoke);

    await port.createPlaylist({ name: "通勤", description: "路上" });
    await port.updatePlaylist({
      playlistId: "playlist-one",
      name: "夜跑",
      description: "晚上",
    });
    await port.deletePlaylist("playlist-one");
    await port.addPlaylistItems({
      playlistId: "playlist-one",
      mediaIds: ["media-one"],
    });
    await port.removePlaylistItems({
      playlistId: "playlist-one",
      mediaIds: ["media-one"],
    });

    expect(invoke.mock.calls).toEqual([
      [
        "playlist_create",
        { request: { name: "通勤", description: "路上" } },
      ],
      [
        "playlist_update",
        {
          request: {
            playlistId: "playlist-one",
            name: "夜跑",
            description: "晚上",
          },
        },
      ],
      ["playlist_delete", { request: { playlistId: "playlist-one" } }],
      [
        "playlist_add_items",
        {
          request: {
            playlistId: "playlist-one",
            mediaIds: ["media-one"],
          },
        },
      ],
      [
        "playlist_remove_items",
        {
          request: {
            playlistId: "playlist-one",
            mediaIds: ["media-one"],
          },
        },
      ],
    ]);
  });

  it("validates ordered scan channel messages before exposing them", async () => {
    const events: unknown[] = [];
    const invoke = vi.fn().mockImplementation(
      async (_command: string, args?: Readonly<Record<string, unknown>>) => {
        const channel = args?.onEvent as {
          emit(message: unknown): void;
        };
        channel.emit({ event: "started", scanId: "scan-1" });
        channel.emit({
          event: "completed",
          scanId: "scan-1",
          visited: 4,
          matched: 2,
          unreadable: 0,
        });
        return emptySnapshot;
      },
    );
    const port = createLibraryPort(invoke, (onMessage) => ({
      emit: onMessage,
    }));

    await expect(
      port.scanDirectory(
        { root: "C:\\Music", recursive: true, includeVideo: true },
        (event) => events.push(event),
      ),
    ).resolves.toEqual({ ok: true, value: emptySnapshot });
    expect(events).toEqual([
      { event: "started", scanId: "scan-1" },
      {
        event: "completed",
        scanId: "scan-1",
        visited: 4,
        matched: 2,
        unreadable: 0,
      },
    ]);
  });

  it("validates the cancellation acknowledgement", async () => {
    const invoke = vi.fn().mockResolvedValue(true);
    const port = createLibraryPort(invoke);

    await expect(port.cancelScan("scan-7")).resolves.toEqual({
      ok: true,
      value: true,
    });
    expect(invoke).toHaveBeenCalledWith("library_cancel_scan", {
      scanId: "scan-7",
    });
  });
});
