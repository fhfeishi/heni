import {
  act,
  fireEvent,
  render,
  renderHook,
  screen,
  waitFor,
} from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type {
  LibraryError,
  LibraryItem,
  LibraryPort,
  LibraryScanEvent,
  LibrarySnapshot,
} from "../../contracts/library";
import type { PlaybackItem } from "../../contracts/playback";
import { err, ok, type Result } from "../../contracts/result";
import { useLibrary } from "./useLibrary";

const item: PlaybackItem = {
  id: "picker-one",
  path: "C:\\Music\\one.flac",
  title: "one.flac",
  kind: "audio",
  durationMs: null,
};

const empty: LibrarySnapshot = { schemaVersion: 1, items: [], playlists: [] };
const imported: LibrarySnapshot = {
  schemaVersion: 1,
  items: [
    {
      ...item,
      available: true,
      metadataStatus: "pending",
      fastMetadata: null,
    },
  ],
  playlists: [],
};

const playlistMethods = (snapshot: LibrarySnapshot) => ({
  readMediaDetails: async () => {
    throw new Error("unused media details test port");
  },
  createPlaylist: async () => ok(snapshot),
  updatePlaylist: async () => ok(snapshot),
  deletePlaylist: async () => ok(snapshot),
  addPlaylistItems: async () => ok(snapshot),
  removePlaylistItems: async () => ok(snapshot),
  relocateMedia: async () => ok(snapshot),
});

const portFixture = (): LibraryPort => ({
  ...playlistMethods(imported),
  readSnapshot: async () => ok(empty),
  readLegacyImportStatus: async () => ok({ state: "not-found" }),
  importLegacy: async () =>
    ok({
      snapshot: imported,
      importedMedia: 1,
      importedPlaylists: 0,
      backupPath: null,
      alreadyImported: false,
    }),
  importFiles: async () => ok(imported),
  scanDirectory: async () => ok(imported),
  cancelScan: async () => ok(true),
});

const deferred = <Value,>() => {
  let settle: ((value: Value) => void) | undefined;
  const promise = new Promise<Value>((resolve) => {
    settle = resolve;
  });
  return {
    promise,
    resolve(value: Value) {
      if (settle === undefined)
        throw new Error("Uninitialized deferred result");
      settle(value);
    },
  };
};

const scanFixture = () => {
  const pending = deferred<Result<LibrarySnapshot, LibraryError>>();
  let listener: ((event: LibraryScanEvent) => void) | undefined;
  const cancelScan = vi
    .fn<LibraryPort["cancelScan"]>()
    .mockResolvedValue(ok(true));
  const port: LibraryPort = {
    ...portFixture(),
    scanDirectory: (_options, onEvent) => {
      listener = onEvent;
      return pending.promise;
    },
    cancelScan,
  };
  return {
    port,
    cancelScan,
    pending,
    emit(event: LibraryScanEvent) {
      if (listener === undefined) throw new Error("Scan not started");
      listener(event);
    },
  };
};

const scanOptions = { root: "C:\\Music", recursive: true, includeVideo: true };

const Harness = ({ port }: { port: LibraryPort }) => {
  const library = useLibrary(port);
  return (
    <div>
      <span>{library.snapshot?.items[0]?.title ?? "empty"}</span>
      <span>{library.scan?.phase ?? "not-scanning"}</span>
      <span>{library.legacyImportStatus?.state ?? "legacy-loading"}</span>
      <button type="button" onClick={() => void library.importFiles([item])}>
        import
      </button>
      <button
        type="button"
        onClick={() =>
          void library.relocateMedia(item.id, "D:\\Recovered\\one.flac")
        }
      >
        relocate
      </button>
      <button
        type="button"
        onClick={() =>
          void library.scanDirectory({
            root: "C:\\Music",
            recursive: true,
            includeVideo: true,
          })
        }
      >
        scan
      </button>
      <button type="button" onClick={() => void library.importLegacy()}>
        legacy
      </button>
      <button
        type="button"
        onClick={() => void library.createPlaylist("  通勤  ")}
      >
        create-playlist
      </button>
    </div>
  );
};

describe("useLibrary", () => {
  it("rejects a second write synchronously, then permits retry after the first settles", async () => {
    const pending = deferred<Result<LibrarySnapshot, LibraryError>>();
    const importFiles = vi
      .fn<LibraryPort["importFiles"]>()
      .mockReturnValue(pending.promise);
    const createPlaylist = vi
      .fn<LibraryPort["createPlaylist"]>()
      .mockResolvedValue(ok(imported));
    const port = { ...portFixture(), importFiles, createPlaylist };
    const { result } = renderHook(() => useLibrary(port));
    await act(async () => undefined);
    await act(async () => {
      void result.current.importFiles([item]);
      expect(await result.current.createPlaylist("duplicate")).toBe(false);
    });
    expect(importFiles).toHaveBeenCalledOnce();
    expect(createPlaylist).not.toHaveBeenCalled();
    expect(result.current.busy).toBe(true);
    await act(async () =>
      pending.resolve(err({ code: "database", message: "fixture" })),
    );
    expect(result.current.busy).toBe(false);
    expect(result.current.snapshot).toEqual(empty);
    await act(async () =>
      expect(await result.current.createPlaylist("retry")).toBe(true),
    );
    expect(createPlaylist).toHaveBeenCalledOnce();
    expect(result.current.error).toBeNull();
  });

  it("isolates a replaced connection from old reads, writes and callbacks", async () => {
    const read = deferred<Result<LibrarySnapshot, LibraryError>>();
    const write = deferred<Result<LibrarySnapshot, LibraryError>>();
    const oldPort: LibraryPort = {
      ...portFixture(),
      readSnapshot: () => read.promise,
      importFiles: () => write.promise,
    };
    const nextPort = portFixture();
    const { result, rerender } = renderHook(({ port }) => useLibrary(port), {
      initialProps: { port: oldPort },
    });
    const oldImport = result.current.importFiles;
    let completion: Promise<boolean> | undefined;
    act(() => {
      completion = oldImport([item]);
    });
    rerender({ port: nextPort });
    expect(result.current.snapshot).toBeNull();
    expect(result.current.busy).toBe(false);
    await act(async () => {
      read.resolve(ok(imported));
      write.resolve(ok(imported));
      expect(await completion).toBe(false);
      expect(await oldImport([item])).toBe(false);
    });
    expect(result.current.snapshot).toEqual(empty);
    expect(result.current.error).toBeNull();
  });

  it.each(["files", "relocate", "legacy"])(
    "does not report late %s success after unmount",
    async (operation) => {
      const pending = deferred<Result<LibrarySnapshot, LibraryError>>();
      const port: LibraryPort = {
        ...portFixture(),
        importFiles: () => pending.promise,
        relocateMedia: () => pending.promise,
        importLegacy: async () => {
          const result = await pending.promise;
          return result.ok
            ? ok({
                snapshot: result.value,
                importedMedia: 1,
                importedPlaylists: 0,
                backupPath: null,
                alreadyImported: false,
              })
            : result;
        },
      };
      const { result, unmount } = renderHook(() => useLibrary(port));
      let completion: Promise<boolean | LibraryItem | null> | undefined;
      act(() => {
        completion =
          operation === "files"
            ? result.current.importFiles([item])
            : operation === "relocate"
              ? result.current.relocateMedia(item.id, "D:\\one.flac")
              : result.current.importLegacy();
      });
      unmount();
      await act(async () => {
        pending.resolve(ok(imported));
        expect(await completion).toBe(operation === "relocate" ? null : false);
      });
    },
  );

  it("contains unexpected read and write rejections without leaving busy stuck", async () => {
    const port: LibraryPort = {
      ...portFixture(),
      readSnapshot: async () => {
        throw new Error("private read path");
      },
      importFiles: async () => {
        throw new Error("private write path");
      },
    };
    const { result } = renderHook(() => useLibrary(port));
    await act(async () => undefined);
    expect(result.current.loading).toBe(false);
    expect(result.current.error?.code).toBe("transport");
    await act(async () =>
      expect(await result.current.importFiles([item])).toBe(false),
    );
    expect(result.current.busy).toBe(false);
    expect(result.current.error?.message).not.toContain("private");
    act(() => result.current.clearError());
    expect(result.current.error).toBeNull();
  });

  it("accepts unrelated late legacy detection without replacing an imported snapshot", async () => {
    const read = deferred<Result<LibrarySnapshot, LibraryError>>();
    const port: LibraryPort = {
      ...portFixture(),
      readSnapshot: () => read.promise,
      readLegacyImportStatus: async () =>
        ok({ state: "ready", mediaCount: 10, playlistCount: 2 }),
    };
    const { result } = renderHook(() => useLibrary(port));
    await act(async () =>
      expect(await result.current.importFiles([item])).toBe(true),
    );
    await act(async () => read.resolve(ok(empty)));
    expect(result.current.snapshot).toEqual(imported);
    expect(result.current.legacyImportStatus?.state).toBe("ready");
  });

  it("does not let late detection undo a successful legacy import", async () => {
    const read = deferred<Result<LibrarySnapshot, LibraryError>>();
    const port: LibraryPort = {
      ...portFixture(),
      readSnapshot: () => read.promise,
      readLegacyImportStatus: async () =>
        ok({ state: "ready", mediaCount: 10, playlistCount: 2 }),
    };
    const { result } = renderHook(() => useLibrary(port));
    await act(async () =>
      expect(await result.current.importLegacy()).toBe(true),
    );
    await act(async () => read.resolve(ok(empty)));
    expect(result.current.snapshot).toEqual(imported);
    expect(result.current.legacyImportStatus?.state).toBe("imported");
  });

  it("cancels a scan whose started event arrives only after unmount", async () => {
    const scan = scanFixture();
    const { result, unmount } = renderHook(() => useLibrary(scan.port));
    act(() => {
      void result.current.scanDirectory(scanOptions);
    });
    unmount();
    await act(async () => {
      scan.emit({ event: "started", scanId: "late" });
      scan.emit({ event: "started", scanId: "late" });
      scan.pending.resolve(ok(imported));
    });
    expect(scan.cancelScan).toHaveBeenCalledExactlyOnceWith("late");
  });

  it("routes late scan cleanup to the old port after replacement", async () => {
    const old = scanFixture();
    const newCancel = vi
      .fn<LibraryPort["cancelScan"]>()
      .mockResolvedValue(ok(true));
    const next = { ...portFixture(), cancelScan: newCancel };
    const { result, rerender } = renderHook(({ port }) => useLibrary(port), {
      initialProps: { port: old.port },
    });
    act(() => {
      void result.current.scanDirectory(scanOptions);
    });
    rerender({ port: next });
    await act(async () => {
      old.emit({ event: "started", scanId: "old" });
      old.emit({
        event: "progress",
        scanId: "old",
        visited: 8,
        matched: 7,
        unreadable: 1,
      });
      old.pending.resolve(ok(imported));
    });
    expect(old.cancelScan).toHaveBeenCalledExactlyOnceWith("old");
    expect(newCancel).not.toHaveBeenCalled();
    expect(result.current.snapshot).toEqual(empty);
    expect(result.current.scan).toBeNull();
  });

  it("ignores foreign progress and does not revive a terminated scan", async () => {
    const scan = scanFixture();
    const { result } = renderHook(() => useLibrary(scan.port));
    act(() => {
      void result.current.scanDirectory(scanOptions);
    });
    act(() => {
      scan.emit({ event: "started", scanId: "current" });
      scan.emit({
        event: "progress",
        scanId: "foreign",
        visited: 999,
        matched: 999,
        unreadable: 0,
      });
    });
    expect(result.current.scan?.visited).toBe(0);
    act(() => {
      scan.emit({
        event: "cancelled",
        scanId: "current",
        visited: 8,
        matched: 6,
        unreadable: 2,
      });
      scan.emit({
        event: "progress",
        scanId: "current",
        visited: 9,
        matched: 7,
        unreadable: 2,
      });
      scan.emit({ event: "started", scanId: "current" });
    });
    expect(result.current.scan?.phase).toBe("cancelled");
    expect(result.current.scan?.visited).toBe(8);
    await act(async () => scan.pending.resolve(ok(imported)));
    expect(result.current.scan?.phase).toBe("cancelled");
  });

  it("deduplicates an in-flight cancellation and permits retry after failure", async () => {
    const scan = scanFixture();
    const cancellation = deferred<Result<boolean, LibraryError>>();
    scan.cancelScan.mockReturnValueOnce(cancellation.promise);
    const { result } = renderHook(() => useLibrary(scan.port));
    act(() => {
      void result.current.scanDirectory(scanOptions);
      scan.emit({ event: "started", scanId: "current" });
    });
    await act(async () => {
      void result.current.cancelScan();
      expect(await result.current.cancelScan()).toBe(false);
    });
    expect(scan.cancelScan).toHaveBeenCalledOnce();
    await act(async () =>
      cancellation.resolve(err({ code: "transport", message: "fixture" })),
    );
    expect(result.current.error?.code).toBe("transport");
    await act(async () => expect(await result.current.cancelScan()).toBe(true));
    expect(scan.cancelScan).toHaveBeenCalledTimes(2);
    expect(result.current.error).toBeNull();
    await act(async () => scan.pending.resolve(ok(imported)));
  });

  it.each([true, false])(
    "ends scanning when the result settles without a terminal event (success %s)",
    async (success) => {
      const scan = scanFixture();
      const { result } = renderHook(() => useLibrary(scan.port));
      act(() => {
        void result.current.scanDirectory(scanOptions);
        scan.emit({ event: "started", scanId: "current" });
      });
      await act(async () =>
        scan.pending.resolve(
          success
            ? ok(imported)
            : err({ code: "database", message: "fixture" }),
        ),
      );
      expect(result.current.busy).toBe(false);
      expect(result.current.scan?.phase).toBe(success ? "finished" : "failed");
      await act(async () =>
        expect(await result.current.cancelScan()).toBe(false),
      );
      expect(scan.cancelScan).not.toHaveBeenCalled();
    },
  );
  it("does not let a late initial read overwrite a completed import", async () => {
    let finishInitialRead: (
      value: Result<LibrarySnapshot, never>,
    ) => void = () => undefined;
    const port: LibraryPort = {
      ...playlistMethods(imported),
      readSnapshot: () =>
        new Promise((resolve) => {
          finishInitialRead = resolve;
        }),
      importFiles: async () => ok(imported),
      readLegacyImportStatus: async () => ok({ state: "not-found" }),
      importLegacy: async () =>
        ok({
          snapshot: imported,
          importedMedia: 1,
          importedPlaylists: 0,
          backupPath: "C:\\backup.json",
          alreadyImported: false,
        }),
      scanDirectory: async () => ok(imported),
      cancelScan: async () => ok(false),
    };
    render(<Harness port={port} />);

    fireEvent.click(screen.getByRole("button", { name: "import" }));
    expect(await screen.findByText("one.flac")).toBeInTheDocument();

    await act(async () => finishInitialRead(ok(empty)));
    expect(screen.getByText("one.flac")).toBeInTheDocument();
  });

  it("cancels an active Rust scan when the React consumer unmounts", async () => {
    const cancelScan = vi.fn().mockResolvedValue(ok(true));
    const port: LibraryPort = {
      ...playlistMethods(imported),
      readSnapshot: async () => ok(empty),
      importFiles: async () => ok(imported),
      readLegacyImportStatus: async () => ok({ state: "not-found" }),
      importLegacy: async () =>
        ok({
          snapshot: imported,
          importedMedia: 1,
          importedPlaylists: 0,
          backupPath: "C:\\backup.json",
          alreadyImported: false,
        }),
      scanDirectory: async (_options, onEvent) => {
        onEvent({ event: "started", scanId: "scan-9" });
        return new Promise(() => undefined);
      },
      cancelScan,
    };
    const rendered = render(<Harness port={port} />);

    fireEvent.click(screen.getByRole("button", { name: "scan" }));
    expect(await screen.findByText("scanning")).toBeInTheDocument();
    rendered.unmount();

    await waitFor(() => expect(cancelScan).toHaveBeenCalledWith("scan-9"));
  });

  it("projects a successful legacy import into the current library", async () => {
    const port: LibraryPort = {
      ...playlistMethods(imported),
      readSnapshot: async () => ok(empty),
      readLegacyImportStatus: async () =>
        ok({ state: "ready", mediaCount: 1, playlistCount: 0 }),
      importLegacy: async () =>
        ok({
          snapshot: imported,
          importedMedia: 1,
          importedPlaylists: 0,
          backupPath: "C:\\backup.json",
          alreadyImported: false,
        }),
      importFiles: async () => ok(imported),
      scanDirectory: async () => ok(imported),
      cancelScan: async () => ok(false),
    };
    render(<Harness port={port} />);

    expect(await screen.findByText("ready")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "legacy" }));

    expect(await screen.findByText("one.flac")).toBeInTheDocument();
    expect(screen.getByText("imported")).toBeInTheDocument();
  });

  it("projects a relocated item while preserving its stable media id", async () => {
    const relocated: LibrarySnapshot = {
      ...imported,
      items: [
        {
          ...item,
          path: "D:\\Recovered\\one.flac",
          title: "recovered.flac",
          available: true,
          metadataStatus: "pending",
          fastMetadata: null,
        },
      ],
    };
    const relocateMedia = vi.fn().mockResolvedValue(ok(relocated));
    const port: LibraryPort = {
      ...playlistMethods(imported),
      readSnapshot: async () => ok(imported),
      readLegacyImportStatus: async () => ok({ state: "not-found" }),
      importLegacy: async () =>
        ok({
          snapshot: imported,
          importedMedia: 0,
          importedPlaylists: 0,
          backupPath: null,
          alreadyImported: true,
        }),
      importFiles: async () => ok(imported),
      relocateMedia,
      scanDirectory: async () => ok(imported),
      cancelScan: async () => ok(false),
    };
    render(<Harness port={port} />);

    expect(await screen.findByText("one.flac")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "relocate" }));

    expect(await screen.findByText("recovered.flac")).toBeInTheDocument();
    expect(relocateMedia).toHaveBeenCalledWith({
      mediaId: "picker-one",
      newPath: "D:\\Recovered\\one.flac",
    });
  });

  it("trims playlist input and projects the transactional snapshot", async () => {
    const withPlaylist: LibrarySnapshot = {
      ...empty,
      playlists: [
        {
          id: "playlist-one",
          name: "通勤",
          description: "",
          itemIds: [],
        },
      ],
    };
    const createPlaylist = vi.fn().mockResolvedValue(ok(withPlaylist));
    const port: LibraryPort = {
      ...playlistMethods(withPlaylist),
      readSnapshot: async () => ok(empty),
      readLegacyImportStatus: async () => ok({ state: "not-found" }),
      importLegacy: async () =>
        ok({
          snapshot: empty,
          importedMedia: 0,
          importedPlaylists: 0,
          backupPath: null,
          alreadyImported: true,
        }),
      importFiles: async () => ok(empty),
      createPlaylist,
      scanDirectory: async () => ok(empty),
      cancelScan: async () => ok(false),
    };
    render(<Harness port={port} />);

    fireEvent.click(screen.getByRole("button", { name: "create-playlist" }));

    await waitFor(() =>
      expect(createPlaylist).toHaveBeenCalledWith({
        name: "通勤",
        description: "",
      }),
    );
  });
});
