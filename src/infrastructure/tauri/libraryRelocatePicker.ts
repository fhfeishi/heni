import { open as openDialog } from "@tauri-apps/plugin-dialog";

import type {
  LibraryItem,
  LibraryRelocatePickerPort,
} from "../../contracts/library";
import { err, ok } from "../../contracts/result";

interface OpenRelocateOptions {
  title: string;
  multiple: false;
  directory: false;
  filters: ReadonlyArray<{
    name: string;
    extensions: ReadonlyArray<string>;
  }>;
}

export type OpenRelocateDialog = (
  options: OpenRelocateOptions,
) => Promise<string | null>;

const audioExtensions = [
  "aac",
  "aiff",
  "alac",
  "flac",
  "m4a",
  "mp3",
  "ogg",
  "opus",
  "wav",
  "wma",
] as const;

const videoExtensions = [
  "avi",
  "flv",
  "m4v",
  "mkv",
  "mov",
  "mp4",
  "mpeg",
  "mpg",
  "ts",
  "webm",
  "wmv",
] as const;

const replacementFilter = (item: LibraryItem) =>
  item.kind === "audio"
    ? { name: "Heni 支持的音频", extensions: audioExtensions }
    : { name: "Heni 支持的视频", extensions: videoExtensions };

export const createLibraryRelocatePicker = (
  openReplacement: OpenRelocateDialog,
): LibraryRelocatePickerPort => ({
  async pickReplacement(item) {
    try {
      return ok(
        await openReplacement({
          title: `为 ${item.title} 选择新文件`,
          multiple: false,
          directory: false,
          filters: [replacementFilter(item)],
        }),
      );
    } catch (cause: unknown) {
      return err({
        code: "transport",
        message:
          cause instanceof Error
            ? cause.message
            : "Windows 文件选择器未能正常打开。",
      });
    }
  },
});

export const tauriLibraryRelocatePicker = createLibraryRelocatePicker(
  openDialog as OpenRelocateDialog,
);
