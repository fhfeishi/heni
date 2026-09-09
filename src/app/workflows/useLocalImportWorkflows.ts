import { useCallback, useState } from "react";

import type {
  LibraryDirectoryPickerPort,
  LibraryError,
  LibraryScanOptions,
} from "../../contracts/library";
import type { LocalMediaPickerPort } from "../../contracts/localMedia";
import type {
  PlaybackError,
  PlaybackItem,
} from "../../contracts/playback";
import type { SettingsSnapshot } from "../../contracts/settings";

export type LocalImportError =
  | Readonly<{ source: "picker"; error: PlaybackError }>
  | Readonly<{ source: "directory-picker"; error: LibraryError }>;

export interface LocalImportWorkflowOptions {
  localMediaPicker: LocalMediaPickerPort;
  libraryDirectoryPicker: LibraryDirectoryPickerPort;
  settings: Pick<SettingsSnapshot, "recursiveScan" | "includeVideo">;
  importFiles(items: ReadonlyArray<PlaybackItem>): Promise<boolean>;
  scanDirectory(options: LibraryScanOptions): Promise<boolean>;
  clearLibraryError(): void;
  onFilesImported(): void;
  onDirectorySelected(): void;
}

export interface LocalImportWorkflow {
  pickingFiles: boolean;
  pickingDirectory: boolean;
  error: LocalImportError | null;
  chooseFiles(): Promise<void>;
  chooseDirectory(): Promise<void>;
  clearError(): void;
}

export const useLocalImportWorkflows = ({
  localMediaPicker,
  libraryDirectoryPicker,
  settings,
  importFiles,
  scanDirectory,
  clearLibraryError,
  onFilesImported,
  onDirectorySelected,
}: LocalImportWorkflowOptions): LocalImportWorkflow => {
  const [pickingFiles, setPickingFiles] = useState(false);
  const [pickingDirectory, setPickingDirectory] = useState(false);
  const [error, setError] = useState<LocalImportError | null>(null);

  const chooseFiles = useCallback(async () => {
    setPickingFiles(true);
    setError(null);
    clearLibraryError();
    const selected = await localMediaPicker.pickAudioFiles();
    setPickingFiles(false);
    if (!selected.ok) {
      setError({ source: "picker", error: selected.error });
      return;
    }
    if (selected.value.length === 0 || !(await importFiles(selected.value))) {
      return;
    }

    onFilesImported();
  }, [
    clearLibraryError,
    importFiles,
    localMediaPicker,
    onFilesImported,
  ]);

  const chooseDirectory = useCallback(async () => {
    setPickingDirectory(true);
    setError(null);
    clearLibraryError();
    const selected = await libraryDirectoryPicker.pickDirectory();
    setPickingDirectory(false);
    if (!selected.ok) {
      setError({ source: "directory-picker", error: selected.error });
      return;
    }
    if (selected.value === null) {
      return;
    }

    onDirectorySelected();
    await scanDirectory({
      root: selected.value,
      recursive: settings.recursiveScan,
      includeVideo: settings.includeVideo,
    });
  }, [
    clearLibraryError,
    libraryDirectoryPicker,
    onDirectorySelected,
    scanDirectory,
    settings.includeVideo,
    settings.recursiveScan,
  ]);

  return {
    pickingFiles,
    pickingDirectory,
    error,
    chooseFiles,
    chooseDirectory,
    clearError: () => setError(null),
  };
};
