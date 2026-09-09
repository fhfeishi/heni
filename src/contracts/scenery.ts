import { z } from "zod";

import type { Result } from "./result";

export const sceneryErrorSchema = z.enum([
  "busy",
  "database",
  "file-unavailable",
  "unsupported-image",
  "image-too-large",
  "collection-too-large",
  "internal",
  "transport",
  "invalid-contract",
]);
export type SceneryError = z.infer<typeof sceneryErrorSchema>;

const collectionPositionSchema = z.object({
  index: z.number().int().min(0).max(11),
  count: z.number().int().min(1).max(12),
}).strict().refine((value) => value.index < value.count);

export const scenerySnapshotSchema = z.discriminatedUnion("state", [
  z.object({ state: z.literal("empty") }).strict(),
  z
    .object({
      state: z.literal("ready"),
      fileName: z.string().min(1).max(1024),
      collection: collectionPositionSchema.optional(),
      dataUrl: z
        .string()
        .max(12_000_000)
        .regex(/^data:image\/(?:png|jpeg);base64,[A-Za-z0-9+/]+={0,2}$/u),
    })
    .strict(),
  z
    .object({
      state: z.literal("unavailable"),
      fileName: z.string().min(1).max(1024),
      reason: z.enum([
        "file-unavailable",
        "unsupported-image",
        "image-too-large",
      ]),
      collection: collectionPositionSchema.optional(),
    })
    .strict(),
]);
export type ScenerySnapshot = Readonly<z.infer<typeof scenerySnapshotSchema>>;
export const emptyScenery: ScenerySnapshot = { state: "empty" };

export interface SceneryPort {
  read(): Promise<Result<ScenerySnapshot, SceneryError>>;
  /** The native picker owns authorization. Null means cancellation, not clearing. */
  choose(): Promise<Result<ScenerySnapshot | null, SceneryError>>;
  clear(): Promise<Result<ScenerySnapshot, SceneryError>>;
  /** Optional for single-image preview ports; the desktop adapter provides it. */
  step?(forward: boolean): Promise<Result<ScenerySnapshot, SceneryError>>;
}
