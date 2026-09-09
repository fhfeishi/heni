import { invoke as tauriInvoke } from "@tauri-apps/api/core";

import { err, ok } from "../../contracts/result";
import {
  sceneryErrorSchema,
  scenerySnapshotSchema,
  type SceneryError,
  type SceneryPort,
} from "../../contracts/scenery";
import type { Invoke } from "./runtimeInfoPort";

const readError = (cause: unknown): SceneryError => {
  const parsed = sceneryErrorSchema.safeParse(cause);
  return parsed.success ? parsed.data : "transport";
};

export const createSceneryPort = (invoke: Invoke): SceneryPort => {
  const readSnapshot = async (command: "scenery_read" | "scenery_clear") => {
    try {
      const parsed = scenerySnapshotSchema.safeParse(await invoke(command));
      if (
        !parsed.success ||
        (command === "scenery_clear" && parsed.data.state !== "empty")
      ) {
        return err("invalid-contract" as const);
      }
      return ok(parsed.data);
    } catch (cause: unknown) {
      return err(readError(cause));
    }
  };

  return {
    read: () => readSnapshot("scenery_read"),
    clear: () => readSnapshot("scenery_clear"),
    async step(forward) {
      try {
        const parsed = scenerySnapshotSchema.safeParse(await invoke("scenery_step", { forward }));
        return parsed.success ? ok(parsed.data) : err("invalid-contract");
      } catch (cause: unknown) {
        return err(readError(cause));
      }
    },
    async choose() {
      try {
        const parsed = scenerySnapshotSchema
          .nullable()
          .safeParse(await invoke("scenery_choose"));
        if (
          !parsed.success ||
          (parsed.data !== null && parsed.data.state !== "ready")
        ) {
          return err("invalid-contract");
        }
        return ok(parsed.data);
      } catch (cause: unknown) {
        return err(readError(cause));
      }
    },
  };
};

export const tauriSceneryPort = createSceneryPort(tauriInvoke);
