import { z } from "zod";

import type { Result } from "./result";

export const fileActionErrorSchema = z.object({
  code: z.enum([
    "invalid-contract",
    "not-found",
    "file-unavailable",
    "file-manager-unavailable",
    "unsupported-platform",
    "transport",
    "internal",
  ]),
  message: z.string().min(1),
});

export type FileActionError = Readonly<
  z.infer<typeof fileActionErrorSchema>
>;

export interface FileActionPort {
  revealMedia(mediaId: string): Promise<Result<void, FileActionError>>;
}
