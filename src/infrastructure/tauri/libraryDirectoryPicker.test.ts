import { describe, expect, it, vi } from "vitest";

import { createLibraryDirectoryPicker } from "./libraryDirectoryPicker";

describe("createLibraryDirectoryPicker", () => {
  it("requests one directory and preserves cancellation", async () => {
    const open = vi.fn().mockResolvedValue(null);
    const picker = createLibraryDirectoryPicker(open);

    await expect(picker.pickDirectory()).resolves.toEqual({
      ok: true,
      value: null,
    });
    expect(open).toHaveBeenCalledWith({
      directory: true,
      multiple: false,
      title: "选择 Heni 曲库文件夹",
    });
  });
});
