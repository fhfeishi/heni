import { open } from "@tauri-apps/plugin-dialog";

import type {
  LibraryDirectoryPickerPort,
  LibraryError,
} from "../../contracts/library";
import { err, ok } from "../../contracts/result";

export type OpenDirectoryDialog = (options: {
  directory: true;
  multiple: false;
  title: string;
}) => Promise<string | null>;

export const createLibraryDirectoryPicker = (
  openDirectory: OpenDirectoryDialog,
): LibraryDirectoryPickerPort => ({
  async pickDirectory() {
    try {
      return ok(
        await openDirectory({
          directory: true,
          multiple: false,
          title: "选择 Heni 曲库文件夹",
        }),
      );
    } catch (cause: unknown) {
      const error: LibraryError = {
        code: "transport",
        message:
          cause instanceof Error
            ? cause.message
            : "The directory picker failed without a readable error.",
      };
      return err(error);
    }
  },
});

export const tauriLibraryDirectoryPicker = createLibraryDirectoryPicker(open);
