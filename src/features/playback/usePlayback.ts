import { useCallback, useEffect, useRef, useState } from "react";

import type {
  PlaybackCommand,
  PlaybackError,
  PlaybackPort,
  PlaybackSnapshot,
  PlaybackUpdate,
} from "../../contracts/playback";
import { err, ok, type Result } from "../../contracts/result";
import {
  createPlaybackClockSample,
  type PlaybackClockSample,
} from "./application/playbackClock";
import { projectPlaybackSnapshot } from "./application/projectPlaybackSnapshot";
import { projectPlaybackPosition } from "./application/projectPlaybackPosition";

export interface PlaybackViewState {
  snapshot: PlaybackSnapshot | null;
  clockSample: PlaybackClockSample | null;
  error: PlaybackError | null;
  loading: boolean;
  busy: boolean;
  dispatch(command: PlaybackCommand): Promise<boolean>;
  clearError(): void;
}

interface PlaybackState {
  readonly port: PlaybackPort;
  readonly snapshot: PlaybackSnapshot | null;
  readonly clockSample: PlaybackClockSample | null;
  readonly error: PlaybackError | null;
  readonly loading: boolean;
  readonly busy: boolean;
}

interface Connection {
  readonly port: PlaybackPort;
  active: boolean;
  reading: boolean;
  revision: number;
  foregroundRevision: number;
  pendingCommands: number;
  pendingForegroundCommands: number;
  suppressedError: string | null;
  latestSnapshot: PlaybackSnapshot | null;
  needsSnapshot: boolean;
  commandError: PlaybackError | null;
}

const initialState = (port: PlaybackPort): PlaybackState => ({
  port,
  snapshot: null,
  clockSample: null,
  error: null,
  loading: true,
  busy: false,
});
const errorKey = (error: PlaybackError) => `${error.code}:${error.message}`;

const readResult = async <Value>(
  operation: () => Promise<Result<Value, PlaybackError>>,
): Promise<Result<Value, PlaybackError>> => {
  try {
    return await operation();
  } catch {
    return err({
      code: "transport",
      message: "The playback connection did not return a response.",
    });
  }
};

const readUpdate = async (
  port: PlaybackPort,
  known: PlaybackSnapshot | null,
): Promise<Result<PlaybackUpdate, PlaybackError>> => {
  if (known !== null) {
    return readResult(() =>
      port.readUpdate({
        generation: known.generation,
        sequence: known.sequence,
      }),
    );
  }
  const result = await readResult(() => port.readSnapshot());
  return result.ok ? ok({ type: "snapshot", snapshot: result.value }) : result;
};

const observe = (
  state: PlaybackState,
  incoming: PlaybackSnapshot,
  sampledAtMs: number,
): PlaybackState => {
  const snapshot = projectPlaybackSnapshot(state.snapshot, incoming);
  return snapshot === state.snapshot
    ? state
    : {
        ...state,
        snapshot,
        clockSample: createPlaybackClockSample(snapshot, sampledAtMs),
      };
};

export const usePlayback = (port: PlaybackPort): PlaybackViewState => {
  const [state, setState] = useState(() => initialState(port));
  const connection = useRef<Connection | null>(null);

  useEffect(() => {
    const session: Connection = {
      port,
      active: true,
      reading: false,
      revision: 0,
      foregroundRevision: 0,
      pendingCommands: 0,
      pendingForegroundCommands: 0,
      suppressedError: null,
      latestSnapshot: null,
      needsSnapshot: false,
      commandError: null,
    };
    connection.current = session;

    const refresh = async (forceSnapshot = false) => {
      if (!session.active || session.reading || session.pendingCommands > 0)
        return;
      session.reading = true;
      const revision = session.revision;
      const result = await readUpdate(
        port,
        forceSnapshot || session.needsSnapshot ? null : session.latestSnapshot,
      );
      const sampledAtMs = performance.now();
      session.reading = false;
      // Even equal-sequence reads started before a command cannot overwrite its result.
      if (!session.active || revision !== session.revision) return;
      let incoming: PlaybackSnapshot | null = null;
      if (result.ok) {
        const update = result.value;
        incoming =
          update.type === "snapshot"
            ? projectPlaybackSnapshot(session.latestSnapshot, update.snapshot)
            : projectPlaybackPosition(session.latestSnapshot, update.position);
        if (update.type === "position" && incoming === session.latestSnapshot) {
          // A mismatched narrow sample cannot reconstruct queue/status. Recover in full.
          session.needsSnapshot = true;
          return;
        }
        session.latestSnapshot = incoming;
        session.needsSnapshot = false;
        if (
          session.commandError === null &&
          incoming?.preferencesError === undefined
        ) {
          session.suppressedError = null;
        }
      }
      const reportedError = result.ok
        ? (session.commandError ?? incoming?.preferencesError ?? null)
        : result.error;
      const displayedError =
        reportedError === null ||
        session.suppressedError === errorKey(reportedError)
          ? null
          : reportedError;
      setState((previous) => {
        const current = previous.port === port ? previous : initialState(port);
        return result.ok && incoming !== null
          ? {
              ...observe(current, incoming, sampledAtMs),
              error: displayedError,
              loading: false,
            }
          : {
              ...current,
              loading: false,
              error: displayedError,
            };
      });
    };

    const onVisibilityChange = () => {
      if (!document.hidden) void refresh(true);
    };
    void refresh();
    // Same status latency, but Rust omits the queue when its state version is unchanged.
    const timer = window.setInterval(() => void refresh(), 300);
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () => {
      session.active = false;
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", onVisibilityChange);
    };
  }, [port]);

  const dispatch = useCallback(
    async (command: PlaybackCommand): Promise<boolean> => {
      const session = connection.current;
      if (session === null || !session.active || session.port !== port)
        return false;
      session.revision += 1;
      const transient = command.type === "preview-volume" || command.type === "cancel-volume-preview";
      const foregroundRevision = transient ? session.foregroundRevision : ++session.foregroundRevision;
      session.pendingCommands += 1;
      if (!transient) {
        session.pendingForegroundCommands += 1;
        session.suppressedError = null;
        session.commandError = null;
        setState((previous) => ({
          ...(previous.port === port ? previous : initialState(port)),
          busy: true,
          error: null,
        }));
      }

      const result = await readResult(() => port.dispatch(command));
      const sampledAtMs = performance.now();
      session.pendingCommands -= 1;
      if (!transient) session.pendingForegroundCommands -= 1;
      if (!session.active) return false;
      if (!transient && foregroundRevision === session.foregroundRevision) {
        session.commandError = result.ok ? null : result.error;
      }
      if (result.ok) {
        session.latestSnapshot = projectPlaybackSnapshot(
          session.latestSnapshot,
          result.value,
        );
      }
      setState((previous) => {
        const current = previous.port === port ? previous : initialState(port);
        const next = result.ok
          ? observe(current, result.value, sampledAtMs)
          : current;
        return {
          ...next,
          busy: session.pendingForegroundCommands > 0,
          loading: false,
          error:
            !transient && foregroundRevision === session.foregroundRevision
              ? result.ok
                ? (next.snapshot?.preferencesError ?? null)
                : result.error
              : current.error,
        };
      });
      return result.ok;
    },
    [port],
  );

  const current = state.port === port ? state : initialState(port);
  return {
    snapshot: current.snapshot,
    clockSample: current.clockSample,
    error: current.error,
    loading: current.loading,
    busy: current.busy,
    dispatch,
    clearError: () => {
      const session = connection.current;
      if (session === null || !session.active || session.port !== port) return;
      session.suppressedError =
        current.error === null ? null : errorKey(current.error);
      session.commandError = null;
      setState((previous) =>
        previous.port === port ? { ...previous, error: null } : previous,
      );
    },
  };
};
