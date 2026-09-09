import { invoke as tauriInvoke, isTauri } from "@tauri-apps/api/core";

import { err, ok, type Result } from "../../contracts/result";
import {
  runtimeInfoSchema,
  type RuntimeInfo,
  type RuntimeInfoError,
  type RuntimeInfoPort,
} from "../../contracts/runtime";

export type Invoke = (
  command: string,
  args?: Readonly<Record<string, unknown>>,
) => Promise<unknown>;

export type RuntimeEnvironment = "browser" | "tauri";

const messageFromUnknown = (cause: unknown): string => {
  if (cause instanceof Error) {
    return cause.message;
  }
  return "Tauri command failed without a readable error.";
};

export const readRuntimeInfo = async (
  invoke: Invoke,
  environment: RuntimeEnvironment = "tauri",
): Promise<Result<RuntimeInfo, RuntimeInfoError>> => {
  if (environment === "browser") {
    return err({
      code: "browser-preview",
      message: "The Tauri runtime is unavailable in a browser preview.",
    });
  }
  try {
    const response = await invoke("runtime_info");
    const parsed = runtimeInfoSchema.safeParse(response);

    if (!parsed.success) {
      return err({
        code: "invalid-contract",
        message: "Rust returned an unexpected runtime-info payload.",
      });
    }

    return ok(parsed.data);
  } catch (cause: unknown) {
    return err({
      code: "transport",
      message: messageFromUnknown(cause),
    });
  }
};

export const tauriRuntimeInfoPort: RuntimeInfoPort = {
  read: () => readRuntimeInfo(tauriInvoke, isTauri() ? "tauri" : "browser"),
};
