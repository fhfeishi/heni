import { z } from "zod";

import type { Result } from "./result";

export const windowModeSchema = z.enum(["main", "mini-player"]);

export type WindowMode = z.infer<typeof windowModeSchema>;

export const windowSnapshotSchema = z.object({
  mode: windowModeSchema,
  maximized: z.boolean(),
  alwaysOnTop: z.boolean(),
  innerWidth: z.number().positive(),
  innerHeight: z.number().positive(),
  scaleFactor: z.number().positive(),
});

export type WindowSnapshot = Readonly<z.infer<typeof windowSnapshotSchema>>;

export type WindowError = Readonly<{
  code:
    | "window-unavailable"
    | "unsupported-platform"
    | "invalid-contract"
    | "transport";
  message: string;
}>;

export interface WindowPort {
  read(): Promise<Result<WindowSnapshot, WindowError>>;
  setMode(mode: WindowMode): Promise<Result<WindowSnapshot, WindowError>>;
}
