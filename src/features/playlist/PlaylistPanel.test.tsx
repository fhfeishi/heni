import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type { LibraryItem, LibraryPlaylist } from "../../contracts/library";
import { PlaylistPanel, type PlaylistPanelProps } from "./PlaylistPanel";

const items: ReadonlyArray<LibraryItem> = [
  {
    id: "media-one",
    path: "C:\\Music\\One.flac",
    title: "One",
    kind: "audio",
    durationMs: 60_000,
    available: true,
    metadataStatus: "pending",
    fastMetadata: null,
  },
  {
    id: "media-two",
    path: "C:\\Music\\Two.flac",
    title: "Two",
    kind: "audio",
    durationMs: 70_000,
    available: true,
    metadataStatus: "pending",
    fastMetadata: null,
  },
];

const playlist = (itemIds: ReadonlyArray<string> = []): LibraryPlaylist => ({
  id: "playlist-one",
  name: "通勤",
  description: "早晚路上",
  itemIds,
});

const callbacks = () => ({
  onPlay: vi.fn(),
  onCreate: vi.fn().mockResolvedValue(true),
  onUpdate: vi.fn().mockResolvedValue(true),
  onDelete: vi.fn().mockResolvedValue(true),
  onAddItems: vi.fn().mockResolvedValue(true),
  onRemoveItems: vi.fn().mockResolvedValue(true),
});

const renderPanel = (overrides: Partial<PlaylistPanelProps> = {}) => {
  const actions = callbacks();
  const props: PlaylistPanelProps = {
    playlists: [playlist()],
    selectedPlaylistId: null,
    items,
    busy: false,
    ...actions,
    ...overrides,
  };
  return { ...render(<PlaylistPanel {...props} />), actions, props };
};

describe("PlaylistPanel", () => {
  it("plays a row by button or double click without reducing the full playlist", () => {
    const selected = playlist(["media-two", "missing", "media-one"]);
    const { actions } = renderPanel({ playlists: [selected] });
    fireEvent.change(screen.getByRole("searchbox", { name: "搜索此歌单" }), { target: { value: "One" } });
    fireEvent.click(screen.getByRole("button", { name: "播放 One" }));
    fireEvent.doubleClick(screen.getByText("One"));
    expect(actions.onPlay).toHaveBeenNthCalledWith(1, selected, "media-one");
    expect(actions.onPlay).toHaveBeenNthCalledWith(2, selected, "media-one");
    fireEvent.doubleClick(screen.getByRole("checkbox", { name: "选择 One" }));
    expect(actions.onPlay).toHaveBeenCalledTimes(2);
  });

  it("locates and focuses the current row even when filtered out", () => {
    renderPanel({ playlists: [playlist(["media-one", "media-two"])], currentMediaId: "media-two" });
    const search = screen.getByRole("searchbox", { name: "搜索此歌单" });
    fireEvent.change(search, { target: { value: "One" } });
    fireEvent.click(screen.getByRole("button", { name: "定位当前播放歌曲" }));
    expect(search).toHaveValue("");
    expect(screen.getByText("Two").closest("li")).toHaveFocus();
    expect(screen.getByText("Two").closest("li")).toHaveAttribute("aria-current", "true");
  });

  it("copies only new songs from another playlist and clears selection when source changes", async () => {
    const { actions } = renderPanel({ playlists: [playlist(["media-one"]), {
      id: "source", name: "来源歌单", description: "", itemIds: ["media-two", "media-one"],
    }] });
    fireEvent.click(screen.getByText("添加歌曲"));
    fireEvent.change(screen.getByRole("combobox", { name: "添加歌曲来源" }), { target: { value: "source" } });
    expect(screen.queryByRole("checkbox", { name: "One" })).toBeNull();
    fireEvent.click(screen.getByRole("checkbox", { name: "Two" }));
    fireEvent.click(screen.getByRole("button", { name: "加入所选（1）" }));
    await waitFor(() => expect(actions.onAddItems).toHaveBeenCalledExactlyOnceWith("playlist-one", ["media-two"]));
    expect(actions.onRemoveItems).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("checkbox", { name: "Two" }));
    fireEvent.change(screen.getByRole("combobox", { name: "添加歌曲来源" }), { target: { value: "" } });
    expect(screen.getByRole("button", { name: "加入所选（0）" })).toBeDisabled();
  });

  it("preserves failed removal selection and limits select-all to visible rows", async () => {
    const onRemoveItems = vi.fn(async () => false);
    renderPanel({ playlists: [playlist(["media-one", "media-two"])], onRemoveItems });
    fireEvent.change(screen.getByRole("searchbox", { name: "搜索此歌单" }), { target: { value: "Two" } });
    fireEvent.click(screen.getByRole("checkbox", { name: "全选当前搜索结果" }));
    fireEvent.click(screen.getByRole("button", { name: "移除所选（1）" }));
    await screen.findByText(/曲目未移除/u);
    expect(onRemoveItems).toHaveBeenCalledExactlyOnceWith("playlist-one", ["media-two"]);
    expect(screen.getByRole("checkbox", { name: "选择 Two" })).toBeChecked();
    fireEvent.change(screen.getByRole("searchbox", { name: "搜索此歌单" }), { target: { value: "" } });
    expect(screen.getByRole("button", { name: "移除所选（0）" })).toBeDisabled();
  });

  it("keeps creation secondary and preserves its draft when saving fails", async () => {
    const onCreate = vi.fn(async () => false);
    renderPanel({ onCreate });
    expect(screen.queryByLabelText("新歌单名称")).toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "新建歌单" }));
    fireEvent.change(screen.getByLabelText("新歌单名称"), { target: { value: "夜行" } });
    fireEvent.click(screen.getByRole("button", { name: "创建歌单" }));
    await waitFor(() => expect(onCreate).toHaveBeenCalledExactlyOnceWith("夜行"));
    expect(screen.getByLabelText("新歌单名称")).toHaveValue("夜行");
    fireEvent.click(screen.getByRole("button", { name: "取消新建" }));
    fireEvent.click(screen.getByRole("button", { name: "新建歌单" }));
    expect(screen.getByLabelText("新歌单名称")).toHaveValue("夜行");
  });

  it("creates and edits playlist metadata through explicit callbacks", async () => {
    const { actions } = renderPanel();

    fireEvent.click(screen.getByRole("button", { name: "新建歌单" }));
    fireEvent.change(screen.getByLabelText("新歌单名称"), {
      target: { value: "  夜跑  " },
    });
    fireEvent.click(screen.getByRole("button", { name: "创建歌单" }));
    await waitFor(() => expect(actions.onCreate).toHaveBeenCalledWith("夜跑"));

    fireEvent.click(screen.getByRole("button", { name: "编辑歌单信息" }));
    fireEvent.change(screen.getByLabelText("名称"), {
      target: { value: "收藏" },
    });
    fireEvent.change(screen.getByLabelText("说明"), {
      target: { value: "喜欢的歌" },
    });
    fireEvent.click(screen.getByRole("button", { name: "保存歌单" }));

    await waitFor(() =>
      expect(actions.onUpdate).toHaveBeenCalledWith(
        "playlist-one",
        "收藏",
        "喜欢的歌",
      ),
    );
  });

  it("confirms destructive deletion and exposes the selected playlist summary", async () => {
    const { actions } = renderPanel({ playlists: [playlist(["media-one"])] });

    expect(screen.getByRole("heading", { name: "通勤", level: 3 })).toBeInTheDocument();
    expect(screen.getByText("早晚路上")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "编辑歌单信息" }));
    fireEvent.click(screen.getByRole("button", { name: "删除歌单" }));

    expect(actions.onDelete).not.toHaveBeenCalled();
    expect(screen.getByRole("alert")).toHaveTextContent("曲库文件不会受影响");
    fireEvent.click(screen.getByRole("button", { name: "确认删除歌单" }));
    await waitFor(() => expect(actions.onDelete).toHaveBeenCalledWith("playlist-one"));
  });

  it("batches additions and removals while preserving playlist ownership", async () => {
    const { actions, rerender, props } = renderPanel();
    fireEvent.click(screen.getByText("添加歌曲"));

    fireEvent.click(screen.getByRole("checkbox", { name: "One" }));
    fireEvent.click(screen.getByRole("checkbox", { name: "Two" }));
    fireEvent.click(screen.getByRole("button", { name: "加入所选（2）" }));
    await waitFor(() =>
      expect(actions.onAddItems).toHaveBeenCalledWith("playlist-one", [
        "media-one",
        "media-two",
      ]),
    );

    rerender(
      <PlaylistPanel
        {...props}
        playlists={[playlist(["media-one", "media-two"])]}
      />,
    );
    fireEvent.click(screen.getByRole("checkbox", { name: "选择 One" }));
    fireEvent.click(screen.getByRole("button", { name: "移除所选（1）" }));

    await waitFor(() =>
      expect(actions.onRemoveItems).toHaveBeenCalledWith("playlist-one", [
        "media-one",
      ]),
    );
    expect(actions.onDelete).not.toHaveBeenCalled();
  });

  it("searches both columns without mutating membership", async () => {
    const { actions } = renderPanel();
    fireEvent.click(screen.getByText("添加歌曲"));

    fireEvent.change(screen.getByRole("searchbox", { name: "搜索可加入曲目" }), {
      target: { value: "two.flac" },
    });
    expect(screen.queryByRole("checkbox", { name: "One" })).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("checkbox", { name: "Two" }));
    fireEvent.click(screen.getByRole("button", { name: "加入所选（1）" }));

    await waitFor(() =>
      expect(actions.onAddItems).toHaveBeenCalledWith("playlist-one", ["media-two"]),
    );
    expect(actions.onRemoveItems).not.toHaveBeenCalled();
    expect(actions.onUpdate).not.toHaveBeenCalled();
  });

  it("plays the complete selected playlist even when its visible list is filtered", () => {
    const selected = playlist(["media-two", "media-one"]);
    const { actions } = renderPanel({ playlists: [selected] });
    fireEvent.change(screen.getByRole("searchbox", { name: "搜索此歌单" }), {
      target: { value: "One" },
    });
    fireEvent.click(screen.getByRole("button", { name: "播放歌单" }));
    expect(actions.onPlay).toHaveBeenCalledExactlyOnceWith(selected);
    expect(actions.onRemoveItems).not.toHaveBeenCalled();
  });

  it("does not offer playback for an entirely unavailable playlist", () => {
    renderPanel({ playlists: [playlist(["missing"])] });
    expect(screen.getByRole("button", { name: "播放歌单" })).toBeDisabled();
    expect(screen.getByText(/播放时将跳过 1 项/u)).toBeInTheDocument();
  });
});
