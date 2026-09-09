import type { FileActionError } from "../../contracts/fileAction";
import type { LibraryError } from "../../contracts/library";
import type { PlaybackError } from "../../contracts/playback";
import type { SettingsError } from "../../contracts/settings";
import type { WindowError } from "../../contracts/window";

export type AppErrorContext =
  | Readonly<{
      source: "picker" | "playback";
      error: PlaybackError;
    }>
  | Readonly<{
      source:
        | "directory-picker"
        | "relocate-picker"
        | "library"
        | "media-details";
      error: LibraryError;
    }>
  | Readonly<{
      source: "window";
      error: WindowError;
    }>
  | Readonly<{
      source: "file-action";
      error: FileActionError;
    }>
  | Readonly<{
      source: "settings";
      error: SettingsError;
    }>;

export type AppRecoveryAction =
  | "choose-audio"
  | "choose-directory"
  | "open-library";

export interface AppErrorPresentation {
  title: string;
  message: string;
  action?: Readonly<{
    kind: AppRecoveryAction;
    label: string;
  }>;
}

type AppErrorCode = AppErrorContext["error"]["code"];

const genericFailure = (
  source: AppErrorContext["source"],
): AppErrorPresentation => {
  if (source === "window") {
    return {
      title: "窗口操作没有完成",
      message: "主窗口仍可继续使用。请稍后再试一次迷你播放器。",
    };
  }
  if (source === "file-action" || source === "settings") {
    return {
      title: source === "settings" ? "设置没有保存" : "文件定位没有完成",
      message:
        source === "settings"
          ? "当前偏好保持不变，请稍后再试。"
          : "曲库记录不会受影响。请确认文件仍然存在后再试。",
    };
  }
  if (
    source === "directory-picker" ||
    source === "relocate-picker" ||
    source === "library" ||
    source === "media-details"
  ) {
    return {
      title: "曲库操作没有完成",
      message: "现有曲库记录不会被删除。请稍后重试刚才的操作。",
    };
  }
  return {
    title: "播放操作没有完成",
    message: "当前队列会被保留。请稍后再次尝试播放。",
  };
};

const assertNever = (code: never): never => {
  throw new Error(`Unhandled app error code: ${String(code)}`);
};

export const presentAppError = ({
  source,
  error,
}: AppErrorContext): AppErrorPresentation => {
  const code: AppErrorCode = error.code;
  switch (code) {
    case "preferences-unavailable":
      return {
        title: "音量偏好暂不可用",
        message:
          "音量设置未能读取或保存。启动恢复失败时会保持静音；请重新调整音量或切换静音后重试。",
      };
    case "path-conflict":
      return {
        title: "这个文件已在曲库中",
        message: "请选择另一个替代文件；现有曲库记录和歌单引用没有变化。",
      };
    case "file-unavailable":
    case "not-found":
      return {
        title: "文件已不可用",
        message:
          "原曲库记录仍会保留。请前往曲库确认缺失项目，重新导入文件后再播放。",
        action: { kind: "open-library", label: "查看曲库" },
      };
    case "path-not-authorized":
      if (source === "directory-picker") {
        return {
          title: "无法访问这个文件夹",
          message: "Heni 没有获得该文件夹的访问权限，请重新选择曲库目录。",
          action: { kind: "choose-directory", label: "重新选择文件夹" },
        };
      }
      if (source === "library" || source === "media-details") {
        return {
          title: "无法访问媒体位置",
          message: "相关记录仍会保留。请前往曲库确认文件状态。",
          action: { kind: "open-library", label: "查看曲库" },
        };
      }
      return {
        title: "无法访问这个位置",
        message: "Heni 没有获得该文件或文件夹的访问权限，请重新选择本地音频。",
        action: { kind: "choose-audio", label: "重新选择" },
      };
    case "unsupported-media-kind":
    case "unsupported-media":
      return {
        title: "暂不支持这个文件",
        message: "请选择受支持的本地音频格式；原文件不会被修改。",
        action: { kind: "choose-audio", label: "选择其他音频" },
      };
    case "decoder-failed":
      return {
        title: "无法解码这首音频",
        message: "文件可能损坏或使用了当前不支持的编码，请尝试其他音频。",
        action: { kind: "choose-audio", label: "选择其他音频" },
      };
    case "audio-device-unavailable":
    case "audio-output":
    case "playback-unavailable":
      return {
        title: "音频输出不可用",
        message: "请确认 Windows 已连接可用的输出设备，然后再次按下播放。",
      };
    case "empty-queue":
      return {
        title: "播放队列为空",
        message: "先选择本地音频，Heni 才能开始播放。",
        action: { kind: "choose-audio", label: "选择音频" },
      };
    case "invalid-current-index":
      return {
        title: "当前曲目已经变化",
        message: "队列会自动保留。请重新选择要播放的曲目。",
      };
    case "duplicate-queue-item":
      return {
        title: "队列中已有这首音频",
        message: "Heni 没有重复添加同一路径的文件。",
      };
    case "metadata-probe-unavailable":
      return {
        title: "详细媒体信息不可用",
        message:
          "播放和基础曲库仍可使用；安装可用的 ffprobe 后可读取完整详情。",
      };
    case "metadata-probe-failed":
      return {
        title: "无法读取媒体详情",
        message: "文件记录和播放队列不会受影响，请稍后再试。",
      };
    case "file-manager-unavailable":
      return {
        title: "无法打开资源管理器",
        message: "媒体文件和曲库记录没有变化，请稍后再试。",
      };
    case "unsupported-schema":
      return {
        title: "旧版数据格式无法识别",
        message: "Heni 没有覆盖原数据。请保留旧版文件并查看迁移说明。",
      };
    case "backup-failed":
      return {
        title: "旧版数据备份失败",
        message: "为保护原数据，本次迁移已经停止，没有继续写入。",
      };
    case "database":
      return source === "settings"
        ? {
            title: "设置暂时无法保存",
            message: "当前偏好保持不变，媒体文件和曲库记录不会受影响。",
          }
        : {
            title: "曲库暂时无法写入",
            message: "现有媒体文件不会受影响。请关闭占用曲库的程序后再试。",
          };
    case "window-unavailable":
      return {
        title: "迷你播放器暂不可用",
        message: "主窗口和播放功能仍可继续使用。",
      };
    case "unsupported-platform":
      return source === "file-action"
        ? {
            title: "当前系统暂不支持文件定位",
            message: "这项能力目前只在 Windows 版本中启用。",
          }
        : {
            title: "迷你播放器暂不可用",
            message: "主窗口和播放功能仍可继续使用。",
          };
    case "invalid-contract":
    case "transport":
    case "internal":
      return genericFailure(source);
    default:
      return assertNever(code);
  }
};
