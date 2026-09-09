import { z } from "zod";

import {
  playbackItemSchema,
  type PlaybackItem,
} from "./playback";
import type { Result } from "./result";

export const libraryMetadataStatusSchema = z.enum([
  "pending",
  "indexed",
  "failed",
]);

export const libraryFastMetadataSchema = z.object({
  codecName: z.string().min(1).nullable(),
  sampleRateHz: z.number().int().positive().nullable(),
  channels: z.number().int().positive().nullable(),
  bitsPerSample: z.number().int().positive().nullable(),
  fileSizeBytes: z.number().int().nonnegative().nullable(),
  estimatedBitRateBps: z.number().int().nonnegative().nullable(),
});

export const libraryItemSchema = playbackItemSchema.extend({
  available: z.boolean(),
  metadataStatus: libraryMetadataStatusSchema,
  fastMetadata: libraryFastMetadataSchema.nullable(),
});

export const mediaStreamDetailsSchema = z.object({
  index: z.number().int(),
  kind: z.enum(["audio", "video", "unknown"]),
  codecName: z.string().min(1).nullable(),
  codecLongName: z.string().min(1).nullable(),
  profile: z.string().min(1).nullable(),
  width: z.number().int().positive().nullable(),
  height: z.number().int().positive().nullable(),
  sampleRateHz: z.number().int().positive().nullable(),
  channels: z.number().int().positive().nullable(),
  durationMs: z.number().int().nonnegative().nullable(),
  frameRate: z.string().min(1).nullable(),
  bitRateBps: z.number().int().nonnegative().nullable(),
  tags: z.record(z.string(), z.string()),
});

export const mediaChapterDetailsSchema = z.object({
  id: z.number().int(),
  startMs: z.number().int().nonnegative(),
  endMs: z.number().int().nonnegative(),
  tags: z.record(z.string(), z.string()),
});

export const mediaDetailsSchema = z.object({
  mediaId: z.string().min(1),
  sourcePath: z.string().min(1),
  provider: z.literal("ffprobe"),
  formatName: z.string().min(1).nullable(),
  formatLongName: z.string().min(1).nullable(),
  durationMs: z.number().int().nonnegative().nullable(),
  sizeBytes: z.number().int().nonnegative().nullable(),
  bitRateBps: z.number().int().nonnegative().nullable(),
  streams: z.array(mediaStreamDetailsSchema).readonly(),
  chapters: z.array(mediaChapterDetailsSchema).readonly(),
  tags: z.record(z.string(), z.string()),
});

export const libraryPlaylistSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  description: z.string(),
  itemIds: z.array(z.string().min(1)).readonly(),
});

export const librarySnapshotSchema = z.object({
  schemaVersion: z.literal(1),
  items: z.array(libraryItemSchema).readonly(),
  playlists: z.array(libraryPlaylistSchema).readonly(),
});

export const legacyImportStatusSchema = z.discriminatedUnion("state", [
  z.object({ state: z.literal("not-found") }),
  z.object({
    state: z.literal("ready"),
    mediaCount: z.number().int().nonnegative(),
    playlistCount: z.number().int().nonnegative(),
  }),
  z.object({ state: z.literal("imported") }),
]);

export const legacyImportOutcomeSchema = z.object({
  snapshot: librarySnapshotSchema,
  importedMedia: z.number().int().nonnegative(),
  importedPlaylists: z.number().int().nonnegative(),
  backupPath: z.string().min(1).nullable(),
  alreadyImported: z.boolean(),
});

export const libraryErrorSchema = z.object({
  code: z.enum([
    "invalid-contract",
    "path-not-authorized",
    "file-unavailable",
    "path-conflict",
    "unsupported-media-kind",
    "unsupported-schema",
    "backup-failed",
    "not-found",
    "database",
    "metadata-probe-unavailable",
    "metadata-probe-failed",
    "transport",
    "internal",
  ]),
  message: z.string().min(1),
});

const scanProgressSchema = z.object({
  scanId: z.string().min(1),
  visited: z.number().int().nonnegative(),
  matched: z.number().int().nonnegative(),
  unreadable: z.number().int().nonnegative(),
});

export const libraryScanEventSchema = z.discriminatedUnion("event", [
  z.object({ event: z.literal("started"), scanId: z.string().min(1) }),
  scanProgressSchema.extend({ event: z.literal("progress") }),
  scanProgressSchema.extend({ event: z.literal("completed") }),
  scanProgressSchema.extend({ event: z.literal("cancelled") }),
]);

export type LibraryItem = Readonly<z.infer<typeof libraryItemSchema>>;
export type MediaDetails = Readonly<z.infer<typeof mediaDetailsSchema>>;
export type LibraryPlaylist = Readonly<
  z.infer<typeof libraryPlaylistSchema>
>;
export type LibrarySnapshot = Readonly<z.infer<typeof librarySnapshotSchema>>;
export type LibraryError = Readonly<z.infer<typeof libraryErrorSchema>>;
export type LibraryScanEvent = Readonly<
  z.infer<typeof libraryScanEventSchema>
>;
export type LegacyImportStatus = Readonly<
  z.infer<typeof legacyImportStatusSchema>
>;
export type LegacyImportOutcome = Readonly<
  z.infer<typeof legacyImportOutcomeSchema>
>;

export interface LibraryScanOptions {
  root: string;
  recursive: boolean;
  includeVideo: boolean;
}

export interface PlaylistCreateInput {
  name: string;
  description: string;
}

export interface PlaylistUpdateInput extends PlaylistCreateInput {
  playlistId: string;
}

export interface PlaylistItemsInput {
  playlistId: string;
  mediaIds: ReadonlyArray<string>;
}

export interface LibraryRelocateInput {
  mediaId: string;
  newPath: string;
}

export interface LibraryDirectoryPickerPort {
  pickDirectory(): Promise<Result<string | null, LibraryError>>;
}

export interface LibraryRelocatePickerPort {
  pickReplacement(
    item: LibraryItem,
  ): Promise<Result<string | null, LibraryError>>;
}

export interface LibraryPort {
  readSnapshot(): Promise<Result<LibrarySnapshot, LibraryError>>;
  readLegacyImportStatus(): Promise<Result<LegacyImportStatus, LibraryError>>;
  importLegacy(): Promise<Result<LegacyImportOutcome, LibraryError>>;
  readMediaDetails(
    mediaId: string,
  ): Promise<Result<MediaDetails, LibraryError>>;
  createPlaylist(
    input: PlaylistCreateInput,
  ): Promise<Result<LibrarySnapshot, LibraryError>>;
  updatePlaylist(
    input: PlaylistUpdateInput,
  ): Promise<Result<LibrarySnapshot, LibraryError>>;
  deletePlaylist(
    playlistId: string,
  ): Promise<Result<LibrarySnapshot, LibraryError>>;
  addPlaylistItems(
    input: PlaylistItemsInput,
  ): Promise<Result<LibrarySnapshot, LibraryError>>;
  removePlaylistItems(
    input: PlaylistItemsInput,
  ): Promise<Result<LibrarySnapshot, LibraryError>>;
  importFiles(
    items: ReadonlyArray<PlaybackItem>,
  ): Promise<Result<LibrarySnapshot, LibraryError>>;
  relocateMedia(
    input: LibraryRelocateInput,
  ): Promise<Result<LibrarySnapshot, LibraryError>>;
  scanDirectory(
    options: LibraryScanOptions,
    onEvent: (event: LibraryScanEvent) => void,
  ): Promise<Result<LibrarySnapshot, LibraryError>>;
  cancelScan(scanId: string): Promise<Result<boolean, LibraryError>>;
}
