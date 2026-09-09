import { invoke as tauriInvoke } from "@tauri-apps/api/core";

import { err, ok } from "../../contracts/result";
import {
  settingsErrorSchema,
  settingsSnapshotSchema,
  settingsUpdateSchema,
  type SettingsError,
  type SettingsPort,
} from "../../contracts/settings";
import type { Invoke } from "./runtimeInfoPort";

const readError = (cause: unknown): SettingsError => {
  const parsed = settingsErrorSchema.safeParse(cause);
  if (parsed.success) {
    return parsed.data;
  }
  return {
    code: "transport",
    message:
      cause instanceof Error
        ? cause.message
        : "Tauri settings command failed without a readable error.",
  };
};

export const createSettingsPort = (invoke: Invoke): SettingsPort => ({
  async read() {
    try {
      const parsed = settingsSnapshotSchema.safeParse(
        await invoke("settings_snapshot"),
      );
      return parsed.success
        ? ok(parsed.data)
        : err({
            code: "invalid-contract",
            message: "Rust returned an unexpected settings snapshot.",
          });
    } catch (cause: unknown) {
      return err(readError(cause));
    }
  },

  async update(request) {
    const validated = settingsUpdateSchema.safeParse(request);
    if (!validated.success) {
      return err({
        code: "invalid-contract",
        message: "Settings update did not match the expected contract.",
      });
    }
    try {
      const parsed = settingsSnapshotSchema.safeParse(
        await invoke("settings_update", { request: validated.data }),
      );
      return parsed.success
        ? ok(parsed.data)
        : err({
            code: "invalid-contract",
            message: "Rust returned an unexpected settings snapshot.",
          });
    } catch (cause: unknown) {
      return err(readError(cause));
    }
  },
});

export const tauriSettingsPort = createSettingsPort(tauriInvoke);
