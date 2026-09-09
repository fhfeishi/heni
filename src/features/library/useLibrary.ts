import { useCallback, useEffect, useRef, useState } from "react";

import type {
  LibraryError,
  LibraryItem,
  LegacyImportStatus,
  LibraryPort,
  LibraryScanEvent,
  LibraryScanOptions,
  LibrarySnapshot,
} from "../../contracts/library";
import type { PlaybackItem } from "../../contracts/playback";
import { err, ok, type Result } from "../../contracts/result";

export interface LibraryViewState {
  snapshot: LibrarySnapshot | null;
  error: LibraryError | null;
  loading: boolean;
  busy: boolean;
  scan: LibraryScanViewState | null;
  legacyImportStatus: LegacyImportStatus | null;
  importFiles(items: ReadonlyArray<PlaybackItem>): Promise<boolean>;
  relocateMedia(mediaId: string, newPath: string): Promise<LibraryItem | null>;
  importLegacy(): Promise<boolean>;
  createPlaylist(name: string, description?: string): Promise<boolean>;
  updatePlaylist(
    playlistId: string,
    name: string,
    description: string,
  ): Promise<boolean>;
  deletePlaylist(playlistId: string): Promise<boolean>;
  addPlaylistItems(
    playlistId: string,
    mediaIds: ReadonlyArray<string>,
  ): Promise<boolean>;
  removePlaylistItems(
    playlistId: string,
    mediaIds: ReadonlyArray<string>,
  ): Promise<boolean>;
  scanDirectory(options: LibraryScanOptions): Promise<boolean>;
  cancelScan(): Promise<boolean>;
  clearError(): void;
}

export interface LibraryScanViewState {
  scanId: string;
  phase: "scanning" | "completed" | "cancelled" | "finished" | "failed";
  visited: number;
  matched: number;
  unreadable: number;
}

interface LibraryState {
  readonly port: LibraryPort;
  readonly snapshot: LibrarySnapshot | null;
  readonly error: LibraryError | null;
  readonly loading: boolean;
  readonly busy: boolean;
  readonly scan: LibraryScanViewState | null;
  readonly legacyImportStatus: LegacyImportStatus | null;
}

interface LibraryConnection {
  readonly port: LibraryPort;
  active: boolean;
  mutating: boolean;
  revision: number;
  activeScanId: string | null;
  cancellationRequestedFor: string | null;
}

const initialState = (port: LibraryPort): LibraryState => ({
  port,
  snapshot: null,
  error: null,
  loading: true,
  busy: false,
  scan: null,
  legacyImportStatus: null,
});

const readLibraryResult = async <Value>(
  operation: () => Promise<Result<Value, LibraryError>>,
): Promise<Result<Value, LibraryError>> => {
  try {
    return await operation();
  } catch {
    return err({
      code: "transport",
      message: "The library connection did not return a response.",
    });
  }
};

const requestScanCancellation = async (
  session: LibraryConnection,
  scanId: string,
): Promise<Result<boolean, LibraryError>> => {
  if (session.cancellationRequestedFor === scanId) return ok(false);
  session.cancellationRequestedFor = scanId;
  const result = await readLibraryResult(() => session.port.cancelScan(scanId));
  if (
    (!result.ok || !result.value) &&
    session.cancellationRequestedFor === scanId
  ) {
    session.cancellationRequestedFor = null;
  }
  return result;
};

export const useLibrary = (port: LibraryPort): LibraryViewState => {
  const [state, setState] = useState(() => initialState(port));
  const connection = useRef<LibraryConnection | null>(null);

  useEffect(() => {
    const session: LibraryConnection = {
      port,
      active: true,
      mutating: false,
      revision: 0,
      activeScanId: null,
      cancellationRequestedFor: null,
    };
    connection.current = session;

    void Promise.all([
      readLibraryResult(() => port.readSnapshot()),
      readLibraryResult(() => port.readLegacyImportStatus()),
    ]).then(([snapshotResult, legacyResult]) => {
      if (!session.active) return;
      setState((previous) => {
        const current = previous.port === port ? previous : initialState(port);
        const untouched = session.revision === 0;
        return {
          ...current,
          snapshot:
            untouched && snapshotResult.ok
              ? snapshotResult.value
              : current.snapshot,
          legacyImportStatus:
            current.legacyImportStatus?.state === "imported" || !legacyResult.ok
              ? current.legacyImportStatus
              : legacyResult.value,
          loading: untouched ? false : current.loading,
          error: !untouched
            ? current.error
            : !snapshotResult.ok
              ? snapshotResult.error
              : !legacyResult.ok
                ? legacyResult.error
                : null,
        };
      });
    });

    return () => {
      session.active = false;
      if (session.activeScanId !== null) {
        void requestScanCancellation(session, session.activeScanId);
      }
    };
  }, [port]);

  const runLibraryMutation = useCallback(
    async <Value>(
      operation: (
        session: LibraryConnection,
      ) => Promise<Result<Value, LibraryError>>,
      project: (current: LibraryState, value: Value) => LibraryState,
    ): Promise<Value | null> => {
      const session = connection.current;
      if (
        session === null ||
        !session.active ||
        session.port !== port ||
        session.mutating
      ) {
        return null;
      }
      // This synchronous guard precedes React's busy render and rejects overlapping writes.
      session.mutating = true;
      session.revision += 1;
      setState((previous) => ({
        ...(previous.port === port ? previous : initialState(port)),
        busy: true,
        error: null,
      }));
      const result = await readLibraryResult(() => operation(session));
      session.mutating = false;
      session.activeScanId = null;
      if (!session.active) return null;
      setState((previous) => {
        const current = previous.port === port ? previous : initialState(port);
        return {
          ...(result.ok ? project(current, result.value) : current),
          busy: false,
          loading: false,
          error: result.ok ? current.error : result.error,
          scan:
            current.scan?.phase === "scanning"
              ? { ...current.scan, phase: result.ok ? "finished" : "failed" }
              : current.scan,
        };
      });
      return result.ok ? result.value : null;
    },
    [port],
  );

  const applySnapshotMutation = useCallback(
    async (
      operation: () => Promise<Result<LibrarySnapshot, LibraryError>>,
    ): Promise<boolean> =>
      (await runLibraryMutation(operation, (current, snapshot) => ({
        ...current,
        snapshot,
      }))) !== null,
    [runLibraryMutation],
  );

  const importFiles = useCallback(
    (items: ReadonlyArray<PlaybackItem>): Promise<boolean> =>
      applySnapshotMutation(() => port.importFiles(items)),
    [applySnapshotMutation, port],
  );

  const relocateMedia = useCallback(
    async (mediaId: string, newPath: string): Promise<LibraryItem | null> => {
      const snapshot = await runLibraryMutation(
        () => port.relocateMedia({ mediaId, newPath }),
        (current, snapshot) => ({ ...current, snapshot }),
      );
      return snapshot?.items.find((item) => item.id === mediaId) ?? null;
    },
    [port, runLibraryMutation],
  );

  const createPlaylist = useCallback(
    (name: string, description = ""): Promise<boolean> =>
      applySnapshotMutation(() =>
        port.createPlaylist({
          name: name.trim(),
          description: description.trim(),
        }),
      ),
    [applySnapshotMutation, port],
  );

  const updatePlaylist = useCallback(
    (playlistId: string, name: string, description: string): Promise<boolean> =>
      applySnapshotMutation(() =>
        port.updatePlaylist({
          playlistId,
          name: name.trim(),
          description: description.trim(),
        }),
      ),
    [applySnapshotMutation, port],
  );

  const deletePlaylist = useCallback(
    (playlistId: string): Promise<boolean> =>
      applySnapshotMutation(() => port.deletePlaylist(playlistId)),
    [applySnapshotMutation, port],
  );

  const addPlaylistItems = useCallback(
    (playlistId: string, mediaIds: ReadonlyArray<string>): Promise<boolean> =>
      applySnapshotMutation(() =>
        port.addPlaylistItems({ playlistId, mediaIds }),
      ),
    [applySnapshotMutation, port],
  );

  const removePlaylistItems = useCallback(
    (playlistId: string, mediaIds: ReadonlyArray<string>): Promise<boolean> =>
      applySnapshotMutation(() =>
        port.removePlaylistItems({ playlistId, mediaIds }),
      ),
    [applySnapshotMutation, port],
  );

  const importLegacy = useCallback(async (): Promise<boolean> => {
    const result = await runLibraryMutation(
      () => port.importLegacy(),
      (current, outcome) => ({
        ...current,
        snapshot: outcome.snapshot,
        legacyImportStatus: { state: "imported" },
      }),
    );
    return result !== null;
  }, [port, runLibraryMutation]);

  const scanDirectory = useCallback(
    async (options: LibraryScanOptions): Promise<boolean> => {
      const result = await runLibraryMutation(
        (session) => {
          const revision = session.revision;
          let started = false;
          setState((current) => ({ ...current, scan: null }));
          const onEvent = (event: LibraryScanEvent) => {
            if (
              !session.active ||
              session.revision !== revision ||
              !session.mutating
            ) {
              // Unmount can precede the first native event; cancel through that old connection.
              if (event.event === "started")
                void requestScanCancellation(session, event.scanId);
              return;
            }
            if (event.event === "started") {
              if (started) return;
              started = true;
              session.activeScanId = event.scanId;
              session.cancellationRequestedFor = null;
              setState((current) => ({
                ...current,
                scan: {
                  scanId: event.scanId,
                  phase: "scanning",
                  visited: 0,
                  matched: 0,
                  unreadable: 0,
                },
              }));
              return;
            }
            if (session.activeScanId !== event.scanId) return;
            setState((current) => ({
              ...current,
              scan: {
                scanId: event.scanId,
                phase: event.event === "progress" ? "scanning" : event.event,
                visited: event.visited,
                matched: event.matched,
                unreadable: event.unreadable,
              },
            }));
            if (event.event !== "progress") session.activeScanId = null;
          };
          return port.scanDirectory(options, onEvent);
        },
        (current, snapshot) => ({ ...current, snapshot }),
      );
      return result !== null;
    },
    [port, runLibraryMutation],
  );

  const cancelScan = useCallback(async (): Promise<boolean> => {
    const session = connection.current;
    if (
      session === null ||
      !session.active ||
      session.port !== port ||
      session.activeScanId === null
    )
      return false;
    const scanId = session.activeScanId;
    if (session.cancellationRequestedFor === scanId) return false;
    setState((current) => ({ ...current, error: null }));
    const result = await requestScanCancellation(session, scanId);
    if (!session.active) return false;
    if (!result.ok && session.activeScanId === scanId) {
      setState((current) => ({ ...current, error: result.error }));
    }
    return result.ok && result.value;
  }, [port]);

  const current = state.port === port ? state : initialState(port);
  return {
    snapshot: current.snapshot,
    error: current.error,
    loading: current.loading,
    busy: current.busy,
    scan: current.scan,
    legacyImportStatus: current.legacyImportStatus,
    importFiles,
    relocateMedia,
    importLegacy,
    createPlaylist,
    updatePlaylist,
    deletePlaylist,
    addPlaylistItems,
    removePlaylistItems,
    scanDirectory,
    cancelScan,
    clearError: () => {
      const session = connection.current;
      if (session === null || !session.active || session.port !== port) return;
      setState((current) => ({ ...current, error: null }));
    },
  };
};
