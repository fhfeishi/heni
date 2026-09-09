import { invoke as tauriInvoke } from "@tauri-apps/api/core";

import {
  playbackErrorSchema,
  playbackSnapshotSchema,
  playbackUpdateSchema,
  type PlaybackCommand,
  type PlaybackError,
  type PlaybackPort,
  type PlaybackSnapshot,
} from "../../contracts/playback";
import { err, ok, type Result } from "../../contracts/result";
import type { Invoke } from "./runtimeInfoPort";
import { tauriVideoOutput } from "./videoOutput";

const invalidContract = (): PlaybackError => ({
  code: "invalid-contract",
  message: "Rust returned an unexpected playback payload.",
});

const transportError = (cause: unknown): PlaybackError => {
  const parsed = playbackErrorSchema.safeParse(cause);
  if (parsed.success) {
    return parsed.data;
  }

  return {
    code: "transport",
    message:
      cause instanceof Error
        ? cause.message
        : "Playback command failed without a readable error.",
  };
};

const parseSnapshot = (
  value: unknown,
): Result<PlaybackSnapshot, PlaybackError> => {
  const parsed = playbackSnapshotSchema.safeParse(value);
  return parsed.success ? ok(parsed.data) : err(invalidContract());
};

export const createPlaybackPort = (invoke: Invoke): PlaybackPort => ({
  async readSnapshot() {
    try {
      return parseSnapshot(await invoke("playback_snapshot"));
    } catch (cause: unknown) {
      return err(transportError(cause));
    }
  },

  async dispatch(command: PlaybackCommand) {
    try {
      return parseSnapshot(await invoke("playback_dispatch", { command }));
    } catch (cause: unknown) {
      return err(transportError(cause));
    }
  },

  async readUpdate(knownVersion) {
    try {
      const parsed = playbackUpdateSchema.safeParse(
        await invoke("playback_poll", { knownVersion }),
      );
      return parsed.success ? ok(parsed.data) : err(invalidContract());
    } catch (cause: unknown) {
      return err(transportError(cause));
    }
  },
});

const nativePlaybackPort = createPlaybackPort(tauriInvoke);
export const tauriPlaybackPort: PlaybackPort = {
  ...nativePlaybackPort,
  async dispatch(command) {
    try {
      return tauriVideoOutput === null ? await nativePlaybackPort.dispatch(command)
        : await tauriVideoOutput.withCommand(command, () => nativePlaybackPort.dispatch(command));
    } catch (cause: unknown) { return err(transportError(cause)); }
  },
};
