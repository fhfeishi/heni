import { z } from "zod";

import type { Result } from "./result";

export const heniThemeIdSchema = z.enum(["studio", "nocturne", "tide", "rose", "iris", "ember"]);
export type HeniThemeId = z.infer<typeof heniThemeIdSchema>;

const sceneryIntensitySchema = z.number().int().min(0).max(100);

export const glassSettingsSchema = z.object({
  material: z.enum(["clear", "soft", "frosted"]),
  transparency: z.number().int().min(0).max(100),
  fog: z.number().int().min(0).max(100).optional(),
}).strict();
export type GlassSettings = Readonly<z.infer<typeof glassSettingsSchema>>;
export const defaultGlassSettings: GlassSettings = { material: "soft", transparency: 35 };
export const glassFog = (value: GlassSettings): number =>
  value.fog ?? ({ clear: 10, soft: 40, frosted: 70 } as const)[value.material];

export const settingsSnapshotSchema = z.object({
  schemaVersion: z.literal(1),
  themeId: heniThemeIdSchema,
  recursiveScan: z.boolean(),
  includeVideo: z.boolean(),
  // V2 storage compatibility only. V3 import workflows never consume this flag.
  autoplayOnLoad: z.boolean(),
  sceneryIntensity: sceneryIntensitySchema.default(100),
  sceneryReveal: z.number().int().min(0).max(300).optional(),
  sceneryAutoRotate: z.boolean().default(false),
  glass: glassSettingsSchema.optional(),
});

export type SettingsSnapshot = Readonly<
  z.infer<typeof settingsSnapshotSchema>
>;

export const defaultSettingsSnapshot: SettingsSnapshot = {
  schemaVersion: 1,
  themeId: "studio",
  recursiveScan: true,
  includeVideo: true,
  autoplayOnLoad: true,
  sceneryIntensity: 100,
  sceneryReveal: 0,
  sceneryAutoRotate: false,
  glass: defaultGlassSettings,
};

export const settingsUpdateSchema = settingsSnapshotSchema
  .omit({ schemaVersion: true })
  // Defaults belong to reads, never to a partial write of unrelated settings.
  .extend({ sceneryIntensity: sceneryIntensitySchema, sceneryAutoRotate: z.boolean() })
  .partial()
  .refine((value) => Object.keys(value).length > 0, {
    message: "A settings update must include at least one preference.",
  });

export type SettingsUpdate = Readonly<z.infer<typeof settingsUpdateSchema>>;

export const settingsErrorSchema = z.object({
  code: z.enum(["invalid-contract", "database", "transport", "internal"]),
  message: z.string().min(1),
});

export type SettingsError = Readonly<z.infer<typeof settingsErrorSchema>>;

export interface SettingsPort {
  read(): Promise<Result<SettingsSnapshot, SettingsError>>;
  update(
    request: SettingsUpdate,
  ): Promise<Result<SettingsSnapshot, SettingsError>>;
}
