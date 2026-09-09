import { Channel, invoke as tauriInvoke } from "@tauri-apps/api/core";

import {
  libraryErrorSchema,
  legacyImportOutcomeSchema,
  legacyImportStatusSchema,
  librarySnapshotSchema,
  libraryScanEventSchema,
  mediaDetailsSchema,
  type LibraryError,
  type LibraryPort,
  type LibrarySnapshot,
  type LibraryScanEvent,
  type LibraryScanOptions,
} from "../../contracts/library";
import type { PlaybackItem } from "../../contracts/playback";
import { err, ok, type Result } from "../../contracts/result";
import type { Invoke } from "./runtimeInfoPort";

const invalidContract = (): LibraryError => ({
  code: "invalid-contract",
  message: "Rust returned an unexpected library payload.",
});

const transportError = (cause: unknown): LibraryError => {
  const parsed = libraryErrorSchema.safeParse(cause);
  if (parsed.success) {
    return parsed.data;
  }
  return {
    code: "transport",
    message:
      cause instanceof Error
        ? cause.message
        : "Library command failed without a readable error.",
  };
};

const parseSnapshot = (
  value: unknown,
): Result<LibrarySnapshot, LibraryError> => {
  const parsed = librarySnapshotSchema.safeParse(value);
  return parsed.success ? ok(parsed.data) : err(invalidContract());
};

const invokeSnapshot = async (
  invoke: Invoke,
  command: string,
  args?: Readonly<Record<string, unknown>>,
): Promise<Result<LibrarySnapshot, LibraryError>> => {
  try {
    return parseSnapshot(await invoke(command, args));
  } catch (cause: unknown) {
    return err(transportError(cause));
  }
};

const toImportItem = (item: PlaybackItem) => ({
  path: item.path,
  title: item.title,
  kind: item.kind,
  durationMs: item.durationMs,
});

export type ScanChannelFactory = (
  onMessage: (message: unknown) => void,
) => unknown;

const createScanChannel: ScanChannelFactory = (onMessage) =>
  new Channel<unknown>(onMessage);

export const createLibraryPort = (
  invoke: Invoke,
  channelFactory: ScanChannelFactory = createScanChannel,
): LibraryPort => ({
  async readSnapshot() {
    return invokeSnapshot(invoke, "library_snapshot");
  },

  async readLegacyImportStatus() {
    try {
      const parsed = legacyImportStatusSchema.safeParse(
        await invoke("library_legacy_import_status"),
      );
      return parsed.success ? ok(parsed.data) : err(invalidContract());
    } catch (cause: unknown) {
      return err(transportError(cause));
    }
  },

  async importLegacy() {
    try {
      const parsed = legacyImportOutcomeSchema.safeParse(
        await invoke("library_import_legacy"),
      );
      return parsed.success ? ok(parsed.data) : err(invalidContract());
    } catch (cause: unknown) {
      return err(transportError(cause));
    }
  },

  async readMediaDetails(mediaId) {
    try {
      const parsed = mediaDetailsSchema.safeParse(
        await invoke("library_media_details", {
          request: { mediaId },
        }),
      );
      return parsed.success ? ok(parsed.data) : err(invalidContract());
    } catch (cause: unknown) {
      return err(transportError(cause));
    }
  },

  async importFiles(items) {
    return invokeSnapshot(invoke, "library_import_files", {
      items: items.map(toImportItem),
    });
  },

  async relocateMedia(input) {
    return invokeSnapshot(invoke, "library_relocate_media", {
      request: input,
    });
  },

  async createPlaylist(input) {
    return invokeSnapshot(invoke, "playlist_create", { request: input });
  },

  async updatePlaylist(input) {
    return invokeSnapshot(invoke, "playlist_update", { request: input });
  },

  async deletePlaylist(playlistId) {
    return invokeSnapshot(invoke, "playlist_delete", {
      request: { playlistId },
    });
  },

  async addPlaylistItems(input) {
    return invokeSnapshot(invoke, "playlist_add_items", {
      request: { ...input, mediaIds: [...input.mediaIds] },
    });
  },

  async removePlaylistItems(input) {
    return invokeSnapshot(invoke, "playlist_remove_items", {
      request: { ...input, mediaIds: [...input.mediaIds] },
    });
  },

  async scanDirectory(
    options: LibraryScanOptions,
    onEvent: (event: LibraryScanEvent) => void,
  ) {
    let invalidEvent = false;
    const channel = channelFactory((message) => {
      const parsed = libraryScanEventSchema.safeParse(message);
      if (parsed.success) {
        onEvent(parsed.data);
      } else {
        invalidEvent = true;
      }
    });
    try {
      const response = await invoke("library_scan_directory", {
        request: options,
        onEvent: channel,
      });
      return invalidEvent ? err(invalidContract()) : parseSnapshot(response);
    } catch (cause: unknown) {
      return err(transportError(cause));
    }
  },

  async cancelScan(scanId) {
    try {
      const response = await invoke("library_cancel_scan", { scanId });
      return typeof response === "boolean"
        ? ok(response)
        : err(invalidContract());
    } catch (cause: unknown) {
      return err(transportError(cause));
    }
  },
});

export const tauriLibraryPort = createLibraryPort(tauriInvoke);
