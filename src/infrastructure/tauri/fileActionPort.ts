import { invoke as tauriInvoke } from "@tauri-apps/api/core";

import {
  fileActionErrorSchema,
  type FileActionError,
  type FileActionPort,
} from "../../contracts/fileAction";
import { err, ok } from "../../contracts/result";
import type { Invoke } from "./runtimeInfoPort";

const transportError = (cause: unknown): FileActionError => {
  const parsed = fileActionErrorSchema.safeParse(cause);
  if (parsed.success) {
    return parsed.data;
  }
  return {
    code: "transport",
    message:
      cause instanceof Error
        ? cause.message
        : "Windows file action failed without a readable error.",
  };
};

export const createFileActionPort = (invoke: Invoke): FileActionPort => ({
  async revealMedia(mediaId) {
    try {
      const response = await invoke("file_action_reveal_media", {
        request: { mediaId },
      });
      return response === null
        ? ok(undefined)
        : err({
            code: "invalid-contract",
            message: "Rust returned an unexpected file action payload.",
          });
    } catch (cause: unknown) {
      return err(transportError(cause));
    }
  },
});

export const tauriFileActionPort = createFileActionPort(tauriInvoke);
