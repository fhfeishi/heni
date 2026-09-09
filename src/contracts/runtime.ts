import { z } from "zod";

import type { Result } from "./result";

export const runtimeInfoSchema = z.object({
  appName: z.literal("Heni"),
  appVersion: z.string().min(1),
  platform: z.enum(["windows", "linux", "macos", "ios", "android", "unknown"]),
});

export type RuntimeInfo = Readonly<z.infer<typeof runtimeInfoSchema>>;

export type RuntimeInfoError =
  | Readonly<{
      code: "browser-preview" | "transport";
      message: string;
    }>
  | Readonly<{
      code: "invalid-contract";
      message: string;
    }>;

export interface RuntimeInfoPort {
  read(): Promise<Result<RuntimeInfo, RuntimeInfoError>>;
}
