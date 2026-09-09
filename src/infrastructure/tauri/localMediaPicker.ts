import { open as openDialog } from "@tauri-apps/plugin-dialog";

import type { LocalMediaPickerPort } from "../../contracts/localMedia";
import type { PlaybackItem } from "../../contracts/playback";
import { err, ok } from "../../contracts/result";

interface OpenAudioOptions {
  title: string;
  multiple: true;
  directory: false;
  filters: ReadonlyArray<{
    name: string;
    extensions: ReadonlyArray<string>;
  }>;
}

export type OpenAudioDialog = (
  options: OpenAudioOptions,
) => Promise<ReadonlyArray<string> | null>;

const titleFromPath = (path: string): string => {
  const name = path.split(/[\\/]/u).at(-1);
  return name === undefined || name.length === 0 ? "未命名音频" : name;
};

const asPlaybackItem = (path: string): PlaybackItem => ({
  id: path,
  path,
  title: titleFromPath(path),
  kind: /\.(mp4|m4v|mov|webm)$/iu.test(path) ? "video" : "audio",
  durationMs: null,
});

const pathKey = (path: string): string =>
  path.replaceAll("/", "\\").toLowerCase();

export const createLocalMediaPicker = (
  openAudioDialog: OpenAudioDialog,
): LocalMediaPickerPort => ({
  async pickAudioFiles() {
    try {
      const selected = await openAudioDialog({
        title: "选择本地音频或视频",
        multiple: true,
        directory: false,
        filters: [
          {
            name: "音频与视频（视频编码由系统支持情况决定）",
            extensions: ["mp3", "m4a", "mp4", "m4v", "mov", "webm", "flac", "wav", "opus", "ogg"],
          },
        ],
      });

      if (selected === null) {
        return ok([]);
      }
      const seen = new Set<string>();
      return ok(
        selected
          .filter((path) => {
            const key = pathKey(path);
            if (seen.has(key)) {
              return false;
            }
            seen.add(key);
            return true;
          })
          .map(asPlaybackItem),
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

export const tauriLocalMediaPicker = createLocalMediaPicker(
  openDialog as OpenAudioDialog,
);
