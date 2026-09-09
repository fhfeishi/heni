import { invoke as tauriInvoke } from "@tauri-apps/api/core";
import { z } from "zod";

import { err, ok, type Result } from "../../contracts/result";
import {
  windowSnapshotSchema,
  type WindowError,
  type WindowMode,
  type WindowPort,
  type WindowSnapshot,
} from "../../contracts/window";

export type Invoke = (
  command: string,
  args?: Readonly<Record<string, unknown>>,
) => Promise<unknown>;

const commandErrorSchema = z.object({
  code: z.enum(["window-unavailable", "unsupported-platform"]),
  message: z.string().min(1),
});

const errorFromUnknown = (cause: unknown): WindowError => {
  const commandError = commandErrorSchema.safeParse(cause);
  if (commandError.success) {
    return commandError.data;
  }
  return {
    code: "transport",
    message:
      cause instanceof Error
        ? cause.message
        : "Tauri window command failed without a readable error.",
  };
};

const invokeSnapshot = async (
  invoke: Invoke,
  command: string,
  args?: Readonly<Record<string, unknown>>,
): Promise<Result<WindowSnapshot, WindowError>> => {
  try {
    const parsed = windowSnapshotSchema.safeParse(await invoke(command, args));
    return parsed.success
      ? ok(parsed.data)
      : err({
          code: "invalid-contract",
          message: "Rust returned an unexpected window snapshot.",
        });
  } catch (cause: unknown) {
    return err(errorFromUnknown(cause));
  }
};

export const createWindowPort = (invoke: Invoke): WindowPort => ({
  read: () => invokeSnapshot(invoke, "window_snapshot"),
  setMode: (mode: WindowMode) =>
    invokeSnapshot(invoke, "window_set_mode", { mode }),
});

export const tauriWindowPort = createWindowPort(tauriInvoke);
