import { act, renderHook } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { err, ok } from "../../contracts/result";
import { defaultSettingsSnapshot } from "../../contracts/settings";
import { useLocalImportWorkflows } from "./useLocalImportWorkflows";

const item = {
  id: "C:\\Music\\one.flac",
  path: "C:\\Music\\one.flac",
  title: "one.flac",
  kind: "audio" as const,
  durationMs: null,
};

describe("useLocalImportWorkflows", () => {
  it("imports selected files before showing the library without a playback dependency", async () => {
    const steps: string[] = [];
    const importFiles = vi.fn(async () => {
      steps.push("import");
      return true;
    });
    const onFilesImported = vi.fn(() => steps.push("show-library"));
    const { result } = renderHook(() =>
      useLocalImportWorkflows({
        localMediaPicker: { pickAudioFiles: async () => ok([item]) },
        libraryDirectoryPicker: { pickDirectory: async () => ok(null) },
        settings: defaultSettingsSnapshot,
        importFiles,
        scanDirectory: async () => true,
        clearLibraryError: vi.fn(),
        onFilesImported,
        onDirectorySelected: vi.fn(),
      }),
    );

    await act(async () => result.current.chooseFiles());

    expect(importFiles).toHaveBeenCalledWith([item]);
    expect(onFilesImported).toHaveBeenCalledOnce();
    expect(steps).toEqual(["import", "show-library"]);
  });

  it("scans a selected directory with the saved traversal preferences", async () => {
    const scanDirectory = vi.fn().mockResolvedValue(true);
    const onDirectorySelected = vi.fn();
    const { result } = renderHook(() =>
      useLocalImportWorkflows({
        localMediaPicker: { pickAudioFiles: async () => ok([]) },
        libraryDirectoryPicker: {
          pickDirectory: async () => ok("C:\\Music"),
        },
        settings: {
          ...defaultSettingsSnapshot,
          recursiveScan: false,
          includeVideo: false,
        },
        importFiles: async () => true,
        scanDirectory,
        clearLibraryError: vi.fn(),
        onFilesImported: vi.fn(),
        onDirectorySelected,
      }),
    );

    await act(async () => result.current.chooseDirectory());

    expect(onDirectorySelected).toHaveBeenCalledOnce();
    expect(scanDirectory).toHaveBeenCalledWith({
      root: "C:\\Music",
      recursive: false,
      includeVideo: false,
    });
  });

  it.each(["cancelled", "picker-failed", "import-failed"] as const)(
    "does not navigate or report success when file selection is %s",
    async (outcome) => {
      const importFiles = vi.fn().mockResolvedValue(false);
      const onFilesImported = vi.fn();
      const { result } = renderHook(() =>
        useLocalImportWorkflows({
          localMediaPicker: {
            pickAudioFiles: async () =>
              outcome === "picker-failed"
                ? err({ code: "transport", message: "picker unavailable" })
                : ok(outcome === "cancelled" ? [] : [item]),
          },
          libraryDirectoryPicker: { pickDirectory: async () => ok(null) },
          settings: defaultSettingsSnapshot,
          importFiles,
          scanDirectory: async () => true,
          clearLibraryError: vi.fn(),
          onFilesImported,
          onDirectorySelected: vi.fn(),
        }),
      );

      await act(async () => result.current.chooseFiles());

      expect(importFiles).toHaveBeenCalledTimes(outcome === "import-failed" ? 1 : 0);
      expect(onFilesImported).not.toHaveBeenCalled();
      expect(result.current.pickingFiles).toBe(false);
      expect(result.current.error?.source ?? null).toBe(
        outcome === "picker-failed" ? "picker" : null,
      );
    },
  );

  it("treats cancelling the directory picker as a no-op", async () => {
    const scanDirectory = vi.fn().mockResolvedValue(true);
    const onDirectorySelected = vi.fn();
    const { result } = renderHook(() =>
      useLocalImportWorkflows({
        localMediaPicker: { pickAudioFiles: async () => ok([]) },
        libraryDirectoryPicker: { pickDirectory: async () => ok(null) },
        settings: defaultSettingsSnapshot,
        importFiles: async () => true,
        scanDirectory,
        clearLibraryError: vi.fn(),
        onFilesImported: vi.fn(),
        onDirectorySelected,
      }),
    );

    await act(async () => result.current.chooseDirectory());

    expect(scanDirectory).not.toHaveBeenCalled();
    expect(onDirectorySelected).not.toHaveBeenCalled();
    expect(result.current.error).toBeNull();
    expect(result.current.pickingDirectory).toBe(false);
  });
});
