import { describe, expect, it } from "vitest";

import type { AppErrorContext } from "./appErrorPresentation";
import { presentAppError } from "./appErrorPresentation";

const rawDiagnostic =
  "rodio backend failed at C:\\Users\\listener\\Private\\song.flac";

describe("presentAppError", () => {
  it.each<AppErrorContext>([
    {
      source: "playback",
      error: { code: "preferences-unavailable", message: rawDiagnostic },
    },
    {
      source: "playback",
      error: { code: "audio-device-unavailable", message: rawDiagnostic },
    },
    {
      source: "picker",
      error: { code: "path-not-authorized", message: rawDiagnostic },
    },
    {
      source: "library",
      error: { code: "database", message: rawDiagnostic },
    },
    {
      source: "media-details",
      error: { code: "metadata-probe-failed", message: rawDiagnostic },
    },
    {
      source: "window",
      error: { code: "window-unavailable", message: rawDiagnostic },
    },
    {
      source: "file-action",
      error: { code: "file-manager-unavailable", message: rawDiagnostic },
    },
    {
      source: "settings",
      error: { code: "database", message: rawDiagnostic },
    },
  ])("does not expose raw diagnostics for $error.code", (errorContext) => {
    expect(JSON.stringify(presentAppError(errorContext))).not.toContain(
      rawDiagnostic,
    );
  });

  it("routes a missing file toward the retained library record", () => {
    expect(
      presentAppError({
        source: "playback",
        error: { code: "file-unavailable", message: rawDiagnostic },
      }),
    ).toEqual({
      title: "文件已不可用",
      message:
        "原曲库记录仍会保留。请前往曲库确认缺失项目，重新导入文件后再播放。",
      action: { kind: "open-library", label: "查看曲库" },
    });
  });

  it("explains a relocation path conflict without exposing diagnostics", () => {
    const presentation = presentAppError({
      source: "library",
      error: {
        code: "path-conflict",
        message: "D:\\Private\\already-owned.flac",
      },
    });

    expect(presentation).toEqual({
      title: "这个文件已在曲库中",
      message: "请选择另一个替代文件；现有曲库记录和歌单引用没有变化。",
    });
    expect(JSON.stringify(presentation)).not.toContain("D:\\Private");
  });

  it("offers a new file choice after a denied path", () => {
    expect(
      presentAppError({
        source: "picker",
        error: { code: "path-not-authorized", message: rawDiagnostic },
      }).action,
    ).toEqual({ kind: "choose-audio", label: "重新选择" });
  });

  it("keeps folder recovery inside the directory picker flow", () => {
    expect(
      presentAppError({
        source: "directory-picker",
        error: { code: "path-not-authorized", message: rawDiagnostic },
      }).action,
    ).toEqual({
      kind: "choose-directory",
      label: "重新选择文件夹",
    });
  });

  it("does not guess which picker caused a generic library path failure", () => {
    expect(
      presentAppError({
        source: "library",
        error: { code: "path-not-authorized", message: rawDiagnostic },
      }).action,
    ).toEqual({ kind: "open-library", label: "查看曲库" });
  });

  it("explains a Windows file-manager failure without exposing diagnostics", () => {
    expect(
      presentAppError({
        source: "file-action",
        error: { code: "file-manager-unavailable", message: rawDiagnostic },
      }),
    ).toEqual({
      title: "无法打开资源管理器",
      message: "媒体文件和曲库记录没有变化，请稍后再试。",
    });
  });
});
