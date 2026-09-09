import { z } from "zod";

import type { Result } from "./result";

export const mediaKindSchema = z.enum(["audio", "video"]);

export const playbackItemSchema = z.object({
  id: z.string().min(1),
  path: z.string().min(1),
  title: z.string().min(1),
  kind: mediaKindSchema,
  durationMs: z.number().int().nonnegative().nullable(),
});

export const repeatModeSchema = z.enum(["none", "all", "one"]);
export const playbackStatusSchema = z.enum([
  "idle",
  "loading",
  "playing",
  "paused",
  "stopped",
  "completed",
  "failed",
]);

export const playbackErrorSchema = z.object({
  code: z.enum([
    "empty-queue",
    "invalid-current-index",
    "invalid-contract",
    "unsupported-media-kind",
    "file-unavailable",
    "path-not-authorized",
    "duplicate-queue-item",
    "unsupported-media",
    "audio-device-unavailable",
    "audio-output",
    "playback-unavailable",
    "preferences-unavailable",
    "decoder-failed",
    "transport",
    "internal",
  ]),
  message: z.string().min(1),
});

export const playbackSnapshotSchema = z
  .object({
    generation: z.number().int().nonnegative(),
    sequence: z.number().int().nonnegative(),
    status: playbackStatusSchema,
    queue: z.array(playbackItemSchema).readonly(),
    currentIndex: z.number().int().nonnegative().nullable(),
    positionMs: z.number().int().nonnegative(),
    durationMs: z.number().int().nonnegative().nullable(),
    volume: z.number().min(0).max(100),
    muted: z.boolean(),
    repeatMode: repeatModeSchema,
    shuffle: z.boolean(),
    preferencesError: playbackErrorSchema.optional(),
  })
  .superRefine((snapshot, context) => {
    const currentIndex = snapshot.currentIndex;
    if (currentIndex !== null && currentIndex >= snapshot.queue.length) {
      context.addIssue({
        code: "custom",
        path: ["currentIndex"],
        message: "currentIndex must point to an item in queue.",
      });
    }

    if (snapshot.queue.length === 0 && snapshot.status !== "idle") {
      context.addIssue({
        code: "custom",
        path: ["status"],
        message: "An empty queue must be idle.",
      });
    }
  });

export const playbackCommandSchema = z.discriminatedUnion("type", [
  z
    .object({
      type: z.literal("replace-queue"),
      queue: z.array(playbackItemSchema),
      currentIndex: z.number().int().nonnegative().nullable(),
      autoplay: z.boolean(),
    })
    .superRefine((command, context) => {
      const hasValidCurrent =
        command.currentIndex !== null &&
        command.currentIndex < command.queue.length;
      const hasValidEmptyQueue =
        command.queue.length === 0 && command.currentIndex === null;

      if (!hasValidCurrent && !hasValidEmptyQueue) {
        context.addIssue({
          code: "custom",
          path: ["currentIndex"],
          message: "A non-empty queue must select a valid current item.",
        });
      }

      const paths = new Set<string>();
      command.queue.forEach((item, index) => {
        const key = item.path.replaceAll("/", "\\").toLowerCase();
        if (paths.has(key)) {
          context.addIssue({
            code: "custom",
            path: ["queue", index, "path"],
            message: "The playback queue cannot contain a duplicate path.",
          });
        }
        paths.add(key);
      });
    }),
  z.object({ type: z.literal("play") }),
  z.object({ type: z.literal("pause") }),
  z.object({ type: z.literal("stop") }),
  z.object({ type: z.literal("next") }),
  z.object({ type: z.literal("previous") }),
  z.object({
    type: z.literal("play-index"),
    index: z.number().int().nonnegative(),
  }),
  z.object({
    type: z.literal("remove-index"),
    index: z.number().int().nonnegative(),
  }),
  z.object({
    type: z.literal("reorder-queue"),
    fromIndex: z.number().int().nonnegative(),
    toIndex: z.number().int().nonnegative(),
  }),
  z.object({
    type: z.literal("refresh-item"),
    item: playbackItemSchema,
  }),
  z.object({
    type: z.literal("enqueue"),
    items: z.array(playbackItemSchema).min(1),
  }),
  z.object({
    type: z.literal("play-next"),
    items: z.array(playbackItemSchema).min(1),
  }),
  z.object({
    type: z.literal("seek"),
    positionMs: z.number().int().nonnegative(),
  }),
  z.object({
    type: z.literal("set-volume"),
    volume: z.number().min(0).max(100),
  }),
  z.object({
    type: z.literal("preview-volume"),
    volume: z.number().min(0).max(100),
    generation: z.number().int().nonnegative(),
    sequence: z.number().int().nonnegative(),
  }),
  z.object({
    type: z.literal("cancel-volume-preview"),
    generation: z.number().int().nonnegative(),
    sequence: z.number().int().nonnegative(),
  }),
  z.object({
    type: z.literal("set-muted"),
    muted: z.boolean(),
  }),
  z.object({
    type: z.literal("set-repeat-mode"),
    repeatMode: repeatModeSchema,
  }),
  z.object({
    type: z.literal("set-shuffle"),
    shuffle: z.boolean(),
  }),
]);

export const playbackVersionSchema = z.object({
  generation: z.number().int().nonnegative(),
  sequence: z.number().int().nonnegative(),
});

export const playbackPositionSchema = playbackVersionSchema.extend({
  status: playbackStatusSchema,
  mediaId: z.string().min(1).nullable(),
  positionMs: z.number().int().nonnegative(),
  durationMs: z.number().int().nonnegative().nullable(),
});

// A position sample never increments the authoritative state version.
export const playbackUpdateSchema = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("snapshot"),
    snapshot: playbackSnapshotSchema,
  }),
  z.object({
    type: z.literal("position"),
    position: playbackPositionSchema,
  }),
]);

export type PlaybackItem = Readonly<z.infer<typeof playbackItemSchema>>;
export type PlaybackStatus = z.infer<typeof playbackStatusSchema>;
export type PlaybackSnapshot = Readonly<z.infer<typeof playbackSnapshotSchema>>;
export type PlaybackCommand = Readonly<z.infer<typeof playbackCommandSchema>>;
export type PlaybackError = Readonly<z.infer<typeof playbackErrorSchema>>;
export type PlaybackVersion = Readonly<z.infer<typeof playbackVersionSchema>>;
export type PlaybackPosition = Readonly<z.infer<typeof playbackPositionSchema>>;
export type PlaybackUpdate = Readonly<z.infer<typeof playbackUpdateSchema>>;

export interface PlaybackPort {
  readSnapshot(): Promise<Result<PlaybackSnapshot, PlaybackError>>;
  readUpdate(
    knownVersion: PlaybackVersion,
  ): Promise<Result<PlaybackUpdate, PlaybackError>>;
  dispatch(
    command: PlaybackCommand,
  ): Promise<Result<PlaybackSnapshot, PlaybackError>>;
}
