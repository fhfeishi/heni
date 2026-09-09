import { act, renderHook } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import type { FileActionPort } from "../../contracts/fileAction";
import { err, ok } from "../../contracts/result";
import { useFileAction } from "./useFileAction";

describe("useFileAction", () => {
  it("tracks the selected media id while Windows reveal is pending", async () => {
    let finish: (
      value: Awaited<ReturnType<FileActionPort["revealMedia"]>>,
    ) => void = () => undefined;
    const port: FileActionPort = {
      revealMedia: () =>
        new Promise((resolve) => {
          finish = resolve;
        }),
    };
    const { result } = renderHook(() => useFileAction(port));

    let reveal = Promise.resolve(false);
    act(() => {
      reveal = result.current.revealMedia("media-one");
    });
    expect(result.current.busyMediaId).toBe("media-one");

    await act(async () => {
      finish(ok(undefined));
      await reveal;
    });
    expect(result.current.busyMediaId).toBeNull();
    expect(result.current.error).toBeNull();
  });

  it("surfaces a typed failure and clears it explicitly", async () => {
    const port: FileActionPort = {
      revealMedia: async () =>
        err({
          code: "file-manager-unavailable",
          message: "shell unavailable",
        }),
    };
    const { result } = renderHook(() => useFileAction(port));

    await act(async () => {
      await result.current.revealMedia("media-one");
    });
    expect(result.current.error?.code).toBe("file-manager-unavailable");

    act(() => result.current.clearError());
    expect(result.current.error).toBeNull();
  });
});
