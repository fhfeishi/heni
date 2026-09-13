import {
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type { FileActionPort } from "../contracts/fileAction";
import type { LocalMediaPickerPort } from "../contracts/localMedia";
import type {
  LibraryPort,
  LibraryScanEvent,
  LibraryScanOptions,
  LibrarySnapshot,
} from "../contracts/library";
import type { PlaybackPort, PlaybackSnapshot } from "../contracts/playback";
import { err, ok } from "../contracts/result";
import type { RuntimeInfoPort } from "../contracts/runtime";
import { defaultSettingsSnapshot } from "../contracts/settings";
import type {
  SettingsPort,
  SettingsSnapshot,
  SettingsUpdate,
} from "../contracts/settings";
import type { WindowMode, WindowPort } from "../contracts/window";
import { App } from "./App";
import { playbackReader } from "../test/playbackReader";

vi.mock("../infrastructure/tauri/sceneryPort", () => ({
  tauriSceneryPort: {
    read: async () => ({ ok: true, value: { state: "empty" } }),
    choose: async () => ({ ok: true, value: null }),
    clear: async () => ({ ok: true, value: { state: "empty" } }),
  },
}));

vi.mock("../infrastructure/tauri/settingsPort", () => {
  const defaults = {
    schemaVersion: 1 as const,
    themeId: "studio" as const,
    recursiveScan: true,
    includeVideo: true,
    autoplayOnLoad: true,
    sceneryIntensity: 100,
    sceneryAutoRotate: false,
  };
  return {
    tauriSettingsPort: {
      read: async () => ({ ok: true as const, value: defaults }),
      update: async (request: Record<string, unknown>) => ({
        ok: true as const,
        value: { ...defaults, ...request },
      }),
    },
  };
});

const mergeSettings = (
  current: SettingsSnapshot,
  update: SettingsUpdate,
): SettingsSnapshot => ({
  glass: update.glass ?? current.glass,
  sceneryReveal: update.sceneryReveal ?? current.sceneryReveal,
  schemaVersion: 1,
  themeId: update.themeId ?? current.themeId,
  recursiveScan: update.recursiveScan ?? current.recursiveScan,
  includeVideo: update.includeVideo ?? current.includeVideo,
  autoplayOnLoad: update.autoplayOnLoad ?? current.autoplayOnLoad,
  sceneryIntensity: update.sceneryIntensity ?? current.sceneryIntensity,
  sceneryAutoRotate: update.sceneryAutoRotate ?? current.sceneryAutoRotate,
});

const emptySnapshot: PlaybackSnapshot = {
  generation: 0,
  sequence: 0,
  status: "idle",
  queue: [],
  currentIndex: null,
  positionMs: 0,
  durationMs: null,
  volume: 100,
  muted: false,
  repeatMode: "all",
  shuffle: false,
};

const emptyLibrary: LibrarySnapshot = {
  schemaVersion: 1,
  items: [],
  playlists: [],
};

const libraryPort = (snapshot = emptyLibrary): LibraryPort => ({
  readSnapshot: async () => ok(snapshot),
  readLegacyImportStatus: async () => ok({ state: "not-found" }),
  importLegacy: async () =>
    ok({
      snapshot,
      importedMedia: 0,
      importedPlaylists: 0,
      backupPath: null,
      alreadyImported: true,
    }),
  readMediaDetails: async () => {
    throw new Error("unused media details test port");
  },
  importFiles: async () => ok(snapshot),
  relocateMedia: async () => ok(snapshot),
  createPlaylist: async () => ok(snapshot),
  updatePlaylist: async () => ok(snapshot),
  deletePlaylist: async () => ok(snapshot),
  addPlaylistItems: async () => ok(snapshot),
  removePlaylistItems: async () => ok(snapshot),
  scanDirectory: async () => ok(snapshot),
  cancelScan: async () => ok(false),
});

describe("App", () => {
  it("pins edge panels without changing settings or playback", async () => {
    const update = vi.fn<SettingsPort["update"]>();
    const { container } = render(<App settingsPort={{ read: async () => ok(defaultSettingsSnapshot), update }} />);
    const pin = await screen.findByRole("button", { name: "固定工具面板" });
    expect(container.querySelector(".app-frame")).toHaveAttribute("data-edge-panels", "auto");
    fireEvent.click(pin);
    expect(pin).toHaveAttribute("aria-pressed", "true");
    expect(container.querySelector(".app-frame")).toHaveAttribute("data-edge-panels", "pinned");
    fireEvent.click(pin);
    expect(pin).toHaveAttribute("aria-pressed", "false");
    expect(update).not.toHaveBeenCalled();
  });
  it("retains playlist context across stage and Mini and plays the unfiltered order", async () => {
    const items = ["One", "Two"].map((title) => ({
      id: title, path: `C:\\Music\\${title}.flac`, title, kind: "audio" as const,
      durationMs: 60_000, available: true, metadataStatus: "pending" as const, fastMetadata: null,
    }));
    const dispatch = vi.fn(async () => ok({ ...emptySnapshot, sequence: 1, queue: items, currentIndex: 0, status: "playing" as const }));
    const windowSnapshot = (mode: WindowMode) => ({
      mode, maximized: false, alwaysOnTop: false,
      innerWidth: 1180, innerHeight: 760, scaleFactor: 1
    });
    render(<App
      runtimeInfoPort={{ read: async () => ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }) }}
      libraryPort={libraryPort({
        schemaVersion: 1, items, playlists: [
          { id: "other", name: "清晨", description: "", itemIds: [] },
          { id: "evening", name: "夜色", description: "慢慢听", itemIds: ["Two", "One"] },
        ]
      })}
      playbackPort={{ ...playbackReader(async () => ok(emptySnapshot)), dispatch }}
      windowPort={{ read: async () => ok(windowSnapshot("main")), setMode: async (mode) => ok(windowSnapshot(mode)) }}
    />);
    await screen.findByText("播放器已就绪");
    fireEvent.click(screen.getByRole("button", { name: "歌单" }));
    fireEvent.click(screen.getByRole("button", { name: /夜色/u }));
    const search = screen.getByRole("searchbox", { name: "搜索此歌单" });
    fireEvent.change(search, { target: { value: "One" } });
    const pane = search.closest(".retained-view");
    if (!(pane instanceof HTMLElement)) throw new Error("Expected retained browse pane");
    pane.scrollTop = 140;
    fireEvent.click(screen.getByRole("button", { name: "播放歌单" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "播放舞台" })).toHaveAttribute("aria-pressed", "true"));
    expect(dispatch).toHaveBeenCalledExactlyOnceWith({
      type: "replace-queue",
      queue: [...items].reverse().map(({ id, path, title, kind, durationMs }) => ({ id, path, title, kind, durationMs })),
      currentIndex: 0, autoplay: true
    });
    expect(pane).toHaveAttribute("hidden");
    expect(pane).toHaveAttribute("inert");
    fireEvent.click(screen.getByRole("button", { name: "歌曲" }));
    expect(screen.getByRole("searchbox", { name: "搜索此歌单" })).toBe(search);
    expect(search).toHaveValue("One");
    expect(pane.scrollTop).toBe(140);
    fireEvent.click(screen.getByRole("button", { name: "进入迷你播放器" }));
    await screen.findByRole("button", { name: "返回主窗口" });
    expect(screen.queryByRole("searchbox", { name: "搜索此歌单" })).toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "返回主窗口" }));
    expect(await screen.findByRole("searchbox", { name: "搜索此歌单" })).toBe(search);
    expect(search).toHaveValue("One");
    expect(dispatch).toHaveBeenCalledTimes(1);
  });

  it("requires playlist replacement consent and retains browsing after playback failure", async () => {
    const item = {
      id: "one", path: "C:\\Music\\one.flac", title: "One", kind: "audio" as const,
      durationMs: 60_000, available: true, metadataStatus: "pending" as const, fastMetadata: null
    };
    const dispatch = vi.fn(async () => err({ code: "decoder-failed" as const, message: "Unavailable" }));
    render(<App
      runtimeInfoPort={{ read: async () => ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }) }}
      libraryPort={libraryPort({ schemaVersion: 1, items: [item], playlists: [{ id: "p", name: "夜色", description: "", itemIds: [item.id] }] })}
      playbackPort={{ ...playbackReader(async () => ok({ ...emptySnapshot, queue: [item], currentIndex: 0 })), dispatch }}
    />);
    await screen.findByText("播放器已就绪");
    fireEvent.click(screen.getByRole("button", { name: "歌单" }));
    fireEvent.click(screen.getByRole("button", { name: "播放歌单" }));
    expect(dispatch).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "保留当前队列" }));
    expect(dispatch).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "播放歌单" }));
    fireEvent.click(screen.getByRole("button", { name: "替换队列并播放" }));
    await waitFor(() => expect(dispatch).toHaveBeenCalledTimes(1));
    expect(screen.getByRole("searchbox", { name: "搜索此歌单" })).toBeVisible();
  });

  it("keeps the chosen song through queue confirmation and skips missing playlist members", async () => {
    const items = ["One", "Two"].map((title) => ({
      id: title, path: `C:\\Music\\${title}.flac`, title, kind: "audio" as const,
      durationMs: 60_000, available: true, metadataStatus: "pending" as const, fastMetadata: null,
    }));
    const dispatch = vi.fn(async () => err({ code: "decoder-failed" as const, message: "Unavailable" }));
    render(<App
      runtimeInfoPort={{ read: async () => ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }) }}
      libraryPort={libraryPort({ schemaVersion: 1, items, playlists: [
        { id: "p", name: "夜色", description: "", itemIds: ["missing", "Two", "One"] },
      ] })}
      playbackPort={{ ...playbackReader(async () => ok({ ...emptySnapshot, queue: items, currentIndex: 0 })), dispatch }}
    />);
    await screen.findByText("播放器已就绪");
    fireEvent.click(screen.getByRole("button", { name: "歌单" }));
    fireEvent.click(screen.getByRole("button", { name: "播放 One" }));
    expect(dispatch).not.toHaveBeenCalled();
    expect(screen.getByRole("alert")).toHaveTextContent("所选曲目");
    fireEvent.click(screen.getByRole("button", { name: "替换队列并播放" }));
    await waitFor(() => expect(dispatch).toHaveBeenCalledExactlyOnceWith({
      type: "replace-queue",
      queue: [...items].reverse().map(({ id, path, title, kind, durationMs }) => ({ id, path, title, kind, durationMs })),
      currentIndex: 1, autoplay: true,
    }));
  });

  it("connects scenery selection to the shell and keeps image failures local", async () => {
    const dispatch = vi.fn(async () => ok(emptySnapshot));
    const clear = vi.fn(async () => ok({ state: "empty" as const }));
    const { container } = render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch,
        }}
        libraryPort={libraryPort()}
        sceneryPort={{
          read: async () => ok({ state: "empty" }),
          choose: async () =>
            ok({
              state: "ready",
              fileName: "海岸.png",
              dataUrl: "data:image/png;base64,AQID",
            }),
          clear,
        }}
      />,
    );
    await screen.findByText("播放器已就绪");
    fireEvent.click(screen.getByLabelText("打开设置"));
    fireEvent.click(screen.getByRole("button", { name: "选择图片" }));
    await screen.findByText("海岸.png");
    const image = container.querySelector(".app-scenery__image");
    if (image === null) throw new Error("Expected the chosen scenery image.");
    fireEvent.load(image);
    expect(container.querySelector(".app-scenery")).toHaveAttribute(
      "data-image-state",
      "ready",
    );
    fireEvent.click(screen.getByRole("button", { name: "曲库" }));
    expect(container.querySelector(".app-scenery")).toHaveClass(
      "app-scenery--browse",
    );
    fireEvent.error(image);
    expect(screen.getByLabelText("打开设置，有待处理事项")).toBeInTheDocument();
    expect(container.querySelector(".app-scenery__image")).toBeNull();
    expect(container.querySelector(".app-notice")).toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "清除背景" }));
    await waitFor(() =>
      expect(screen.getByText("跟随主题，不使用图片")).toBeInTheDocument(),
    );
    expect(clear).toHaveBeenCalledOnce();
    expect(dispatch).not.toHaveBeenCalled();
  });

  it("renders validated information from injected desktop ports", async () => {
    const runtimeInfoPort: RuntimeInfoPort = {
      read: async () =>
        ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
    };
    const playbackPort: PlaybackPort = {
      ...playbackReader(async () => ok(emptySnapshot)),
      dispatch: async () => ok(emptySnapshot),
    };
    const localMediaPicker: LocalMediaPickerPort = {
      pickAudioFiles: async () => ok([]),
    };

    render(
      <App
        runtimeInfoPort={runtimeInfoPort}
        playbackPort={playbackPort}
        localMediaPicker={localMediaPicker}
        libraryPort={libraryPort()}
      />,
    );

    expect(screen.getByText("正在准备播放器")).toBeInTheDocument();
    expect(await screen.findByText("播放器已就绪")).toBeInTheDocument();
    expect(await screen.findByText("等待选择")).toBeInTheDocument();
    const brand = screen.getByRole("button", { name: "转到正在播放" });
    expect(brand).toHaveTextContent(/^heni$/u);
    expect(brand.querySelector(".brand-mark")).toBeNull();
  });

  it("keeps workspace copy in Chinese and artwork free of single-letter branding", async () => {
    const { container } = render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch: async () => ok(emptySnapshot),
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={libraryPort()}
      />,
    );

    expect(await screen.findByText("播放器已就绪")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "转到正在播放" }),
    ).toHaveTextContent(/^heni$/u);

    const workspaces = [
      ["正在播放", "聆听时刻"],
      ["曲库", "我的音乐"],
      ["歌单", "创建歌单后，浏览歌单不会打断当前播放队列。"],
      ["播放队列", "接下来播放"],
    ] as const;

    for (const [name, heading] of workspaces) {
      fireEvent.click(screen.getByRole("button", { name }));
      expect(screen.getByText(heading)).toBeInTheDocument();
      expect(container).not.toHaveTextContent(
        /SQLITE|LISTENING CONSOLE|LOCAL FIRST|ACTIVE PLAYBACK SESSION|PLAYLISTS|ON-DEMAND/u,
      );
      expect(screen.queryByText(/^H$/u)).toBeNull();
      for (const artwork of container.querySelectorAll(
        ".mini-artwork, .vinyl-ring",
      )) {
        expect(artwork.textContent).toBe("");
      }
    }
  });

  it("presents browser preview mode without surfacing expected IPC failures", async () => {
    const readPlayback = vi
      .fn()
      .mockResolvedValue(
        err({ code: "transport" as const, message: "Tauri unavailable" }),
      );
    const readLibrary = vi
      .fn()
      .mockResolvedValue(
        err({ code: "transport" as const, message: "Tauri unavailable" }),
      );

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            err({ code: "browser-preview", message: "preview" }),
        }}
        playbackPort={{
          ...playbackReader(readPlayback),
          dispatch: async () => err({ code: "transport", message: "preview" }),
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={{
          ...libraryPort(),
          readSnapshot: readLibrary,
        }}
        settingsPort={{
          read: async () => err({ code: "transport", message: "preview" }),
          update: async () => err({ code: "transport", message: "preview" }),
        }}
      />,
    );

    expect(await screen.findByText("界面预览模式")).toBeInTheDocument();
    await waitFor(() => {
      expect(readPlayback).toHaveBeenCalled();
      expect(readLibrary).toHaveBeenCalled();
    });
    expect(screen.queryByRole("alert")).toBeNull();
    expect(screen.queryByText(/设置暂未保存/u)).toBeNull();
  });

  it("marks a failed desktop runtime handshake as blocked", async () => {
    render(
      <App
        runtimeInfoPort={{
          read: async () => err({ code: "transport", message: "offline" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch: async () => ok(emptySnapshot),
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={libraryPort()}
      />,
    );

    expect(await screen.findByText("播放器暂不可用")).toBeInTheDocument();
  });

  it("switches one main view at a time without mutating playback", async () => {
    const dispatch = vi.fn().mockResolvedValue(ok(emptySnapshot));

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch,
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={libraryPort()}
      />,
    );

    expect(
      screen.getByRole("heading", { name: "开始聆听" }),
    ).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "本地曲库" })).toBeNull();
    expect(screen.getByLabelText("播放控制")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "曲库" }));

    expect(
      await screen.findByRole("heading", { name: "本地曲库" }),
    ).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "开始聆听" })).toBeNull();
    expect(screen.getByLabelText("播放控制")).toBeInTheDocument();
    expect(dispatch).not.toHaveBeenCalled();
  });

  it.each([true, false])("imports without interrupting playback when legacy autoplay is %s", async (autoplayOnLoad) => {
    const item = {
      id: "C:\\Music\\one.flac",
      path: "C:\\Music\\one.flac",
      title: "one.flac",
      kind: "audio" as const,
      durationMs: null,
    };
    const loaded: PlaybackSnapshot = {
      ...emptySnapshot,
      generation: 1,
      status: "playing",
      queue: [{ ...item, id: "existing", title: "already playing" }],
      currentIndex: 0,
      durationMs: 60_000,
    };
    const dispatch = vi.fn().mockResolvedValue(ok(loaded));
    const importFiles = vi.fn().mockResolvedValue(
      ok({
        schemaVersion: 1,
        items: [
          {
            ...item,
            available: true,
            metadataStatus: "pending",
            fastMetadata: null,
          },
        ],
        playlists: [],
      }),
    );
    const playbackPort: PlaybackPort = {
      ...playbackReader(async () => ok(loaded)),
      dispatch,
    };

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={playbackPort}
        localMediaPicker={{ pickAudioFiles: async () => ok([item]) }}
        libraryPort={{
          ...libraryPort(),
          importFiles,
        }}
        settingsPort={{
          read: async () =>
            ok({
              schemaVersion: 1,
              themeId: "studio",
              recursiveScan: true,
              includeVideo: true,
              autoplayOnLoad,
              sceneryIntensity: 100,
              sceneryAutoRotate: false,
            }),
          update: async () => {
            throw new Error("unused settings update");
          },
        }}
      />,
    );

    await act(async () => undefined);
    fireEvent.click(screen.getByRole("button", { name: "曲库" }));
    fireEvent.click(screen.getByRole("button", { name: "导入音频文件" }));

    expect(
      await screen.findByRole("button", { name: "播放 one.flac" }),
    ).toBeInTheDocument();
    expect(dispatch).not.toHaveBeenCalled();
    expect(screen.getByLabelText("播放控制")).toHaveTextContent("already playing");
    expect(importFiles).toHaveBeenCalledWith([item]);
  });

  it("keeps local import available while settings are still hydrating", async () => {
    const item = {
      id: "C:\\Music\\early.flac",
      path: "C:\\Music\\early.flac",
      title: "early.flac",
      kind: "audio" as const,
      durationMs: null,
    };
    const loaded: PlaybackSnapshot = {
      ...emptySnapshot,
      generation: 1,
      sequence: 1,
      status: "playing",
      queue: [item],
      currentIndex: 0,
    };
    const dispatch = vi.fn().mockResolvedValue(ok(loaded));
    const pendingSettings = new Promise<
      Awaited<ReturnType<SettingsPort["read"]>>
    >(() => undefined);

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch,
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([item]) }}
        libraryPort={{
          ...libraryPort(),
          importFiles: async () => ok(emptyLibrary),
        }}
        settingsPort={{
          read: () => pendingSettings,
          update: async () => {
            throw new Error("unused settings update");
          },
        }}
      />,
    );

    const chooseFiles = screen.getByRole("button", {
      name: "选择媒体文件",
    });
    expect(chooseFiles).not.toBeDisabled();
    fireEvent.click(chooseFiles);

    expect(await screen.findByRole("heading", { name: "本地曲库" })).toBeInTheDocument();
    expect(dispatch).not.toHaveBeenCalled();
  });

  it("starts a queue from the persisted SQLite library", async () => {
    const item = {
      id: "c:\\music\\one.flac",
      path: "C:\\Music\\One.flac",
      title: "One.flac",
      kind: "audio" as const,
      durationMs: 60_000,
      available: true,
      metadataStatus: "indexed" as const,
      fastMetadata: {
        codecName: "flac",
        sampleRateHz: 48_000,
        channels: 2,
        bitsPerSample: 24,
        fileSizeBytes: 1_024,
        estimatedBitRateBps: 1_411_200,
      },
    };
    const dispatch = vi.fn().mockResolvedValue(ok(emptySnapshot));

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch,
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={libraryPort({
          schemaVersion: 1,
          items: [item],
          playlists: [],
        })}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "曲库" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "播放 One.flac" }),
    );

    await waitFor(() =>
      expect(dispatch).toHaveBeenCalledWith({
        type: "replace-queue",
        queue: [
          {
            id: item.id,
            path: item.path,
            title: item.title,
            kind: item.kind,
            durationMs: item.durationMs,
          },
        ],
        currentIndex: 0,
        autoplay: true,
      }),
    );

    fireEvent.click(screen.getByRole("button", { name: "曲库" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "更多操作 One.flac" }),
    );
    const playNext = await screen.findByRole("button", {
      name: "下一首播放 One.flac",
    });
    await waitFor(() => expect(playNext).not.toBeDisabled());
    fireEvent.click(playNext);
    await waitFor(() =>
      expect(dispatch).toHaveBeenCalledWith({
        type: "play-next",
        items: [
          {
            id: item.id,
            path: item.path,
            title: item.title,
            kind: item.kind,
            durationMs: item.durationMs,
          },
        ],
      }),
    );

    const enqueue = screen.getByRole("button", {
      name: "加入队列 One.flac",
    });
    await waitFor(() => expect(enqueue).not.toBeDisabled());
    fireEvent.click(enqueue);
    await waitFor(() =>
      expect(dispatch).toHaveBeenCalledWith({
        type: "enqueue",
        items: [
          {
            id: item.id,
            path: item.path,
            title: item.title,
            kind: item.kind,
            durationMs: item.durationMs,
          },
        ],
      }),
    );
  });

  it("browses playlists without mutating the active playback queue", async () => {
    const dispatch = vi.fn().mockResolvedValue(ok(emptySnapshot));
    const playlistLibrary: LibrarySnapshot = {
      ...emptyLibrary,
      playlists: [
        { id: "commute", name: "通勤", description: "", itemIds: [] },
        { id: "running", name: "夜跑", description: "", itemIds: [] },
      ],
    };

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch,
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={libraryPort(playlistLibrary)}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "歌单" }));
    fireEvent.click(await screen.findByRole("button", { name: /夜跑/ }));
    fireEvent.change(screen.getByRole("searchbox", { name: "搜索此歌单" }), {
      target: { value: "不会命中" },
    });
    fireEvent.click(screen.getByRole("button", { name: "使用潮汐主题" }));

    expect(dispatch).not.toHaveBeenCalled();
    expect(
      screen.getByRole("heading", { name: "夜跑", level: 3 }),
    ).toBeInTheDocument();
    await waitFor(() =>
      expect(document.querySelector(".app-frame")).toHaveAttribute(
        "data-theme",
        "tide",
      ),
    );
  });

  it("routes queue selection and transport controls through typed commands", async () => {
    const queue = [
      {
        id: "C:\\Music\\one.flac",
        path: "C:\\Music\\one.flac",
        title: "one.flac",
        kind: "audio" as const,
        durationMs: 60_000,
      },
      {
        id: "C:\\Music\\two.flac",
        path: "C:\\Music\\two.flac",
        title: "two.flac",
        kind: "audio" as const,
        durationMs: 70_000,
      },
    ];
    const queued: PlaybackSnapshot = {
      ...emptySnapshot,
      generation: 1,
      status: "playing",
      queue,
      currentIndex: 0,
      durationMs: 60_000,
    };
    const dispatch = vi.fn().mockResolvedValue(ok(queued));

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{ ...playbackReader(async () => ok(queued)), dispatch }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={libraryPort()}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "播放队列" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "播放 two.flac" }),
    );
    await waitFor(() =>
      expect(dispatch).toHaveBeenCalledWith({ type: "play-index", index: 1 }),
    );

    fireEvent.click(screen.getByRole("button", { name: "下一首" }));
    await waitFor(() =>
      expect(dispatch).toHaveBeenCalledWith({ type: "next" }),
    );

    fireEvent.click(
      screen.getByRole("button", { name: "从队列移除 two.flac" }),
    );
    await waitFor(() =>
      expect(dispatch).toHaveBeenCalledWith({ type: "remove-index", index: 1 }),
    );
  });

  it("scans a selected directory with ordered progress", async () => {
    const scanDirectory = vi.fn(
      async (
        _options: LibraryScanOptions,
        onEvent: (event: LibraryScanEvent) => void,
      ) => {
        onEvent({ event: "started", scanId: "scan-1" });
        onEvent({
          event: "completed",
          scanId: "scan-1",
          visited: 12,
          matched: 3,
          unreadable: 0,
        });
        return ok(emptyLibrary);
      },
    );

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch: async () => ok(emptySnapshot),
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={{
          ...libraryPort(),
          scanDirectory,
        }}
        libraryDirectoryPicker={{
          pickDirectory: async () => ok("C:\\Music"),
        }}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "曲库" }));
    fireEvent.click(await screen.findByRole("button", { name: "导入文件夹" }));

    await waitFor(() =>
      expect(scanDirectory).toHaveBeenCalledWith(
        {
          root: "C:\\Music",
          recursive: true,
          includeVideo: true,
        },
        expect.any(Function),
      ),
    );
    expect(
      await screen.findByText("扫描完成：匹配 3 个媒体文件"),
    ).toBeInTheDocument();
  });

  it("previews glass independently of images and retains failed drafts for retry", async () => {
    const restored = { ...defaultSettingsSnapshot, glass: { material: "soft" as const, transparency: 35 } };
    const update = vi.fn<SettingsPort["update"]>()
      .mockResolvedValueOnce(err({ code: "database", message: "fixture" }))
      .mockImplementation(async (request) => ok({ ...mergeSettings(restored, request), glass: request.glass ?? restored.glass }));
    const { container } = render(<App settingsPort={{ read: async () => ok(restored), update }} />);
    const slider = await screen.findByRole("slider", { name: "玻璃通透度" });
    await waitFor(() => expect(slider).toBeEnabled());
    fireEvent.click(screen.getByRole("button", { name: "清透" }));
    expect(slider).toHaveValue("70");
    fireEvent.change(slider, { target: { value: "100" } });
    expect(container.querySelector(".app-frame")).toHaveStyle({ "--glass-fill": "40%" });
    expect(update).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "取消预览" }));
    expect(slider).toHaveValue("35");
    const fog = screen.getByRole("slider", { name: "玻璃雾度" });
    expect(fog).toHaveValue("40");
    fireEvent.change(fog, { target: { value: "0" } });
    expect(container.querySelector(".app-frame")).toHaveStyle({ "--glass-blur": "0px" });
    expect(slider).toHaveValue("35");
    expect(screen.getByRole("button", { name: "保存材质" })).toBeEnabled();
    fireEvent.change(slider, { target: { value: "80" } });
    fireEvent.click(screen.getByRole("button", { name: "保存材质" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "保存材质" })).toBeEnabled());
    expect(slider).toHaveValue("80");
    fireEvent.click(screen.getByRole("button", { name: "保存材质" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "保存材质" })).toBeDisabled());
    expect(update).toHaveBeenLastCalledWith({ glass: { material: "soft", transparency: 80, fog: 0 } });
    expect(slider).toHaveValue("80");
  });

  it("previews intensity without writing, retains failed drafts, and restores saved intensity", async () => {
    const restored = { ...defaultSettingsSnapshot, sceneryIntensity: 65 };
    const update = vi.fn<SettingsPort["update"]>()
      .mockResolvedValueOnce(err({ code: "database", message: "fixture failure" }))
      .mockImplementation(async (request) => ok(mergeSettings(restored, request)));
    const { container } = render(
      <App
        settingsPort={{ read: async () => ok(restored), update }}
        sceneryPort={{
          read: async () => ok({ state: "ready", fileName: "fixture.png", dataUrl: "data:image/png;base64,AAAA" }),
          choose: async () => ok(null),
          clear: async () => ok({ state: "empty" }),
        }}
      />,
    );
    const slider = await screen.findByRole("slider", { name: "背景强度" });
    await waitFor(() => expect(slider).toHaveValue("65"));
    fireEvent.change(slider, { target: { value: "0" } });
    expect(container.querySelector(".app-scenery")).toHaveStyle({ "--scenery-intensity": "0" });
    expect(update).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "取消调整" }));
    expect(slider).toHaveValue("65");
    fireEvent.change(slider, { target: { value: "35" } });
    fireEvent.click(screen.getByRole("button", { name: "保存强度" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "保存强度" })).toBeEnabled());
    expect(slider).toHaveValue("35");
    fireEvent.click(screen.getByRole("button", { name: "保存强度" }));
    await waitFor(() => expect(update).toHaveBeenCalledTimes(2));
    await waitFor(() => expect(screen.getByRole("button", { name: "保存强度" })).toBeDisabled());
    expect(update).toHaveBeenLastCalledWith({ sceneryIntensity: 35 });
    expect(slider).toHaveValue("35");
  });

  it("previews reveal without writes, cancels and retries failed saves independently", async () => {
    const restored = { ...defaultSettingsSnapshot, sceneryIntensity: 65, sceneryReveal: 20 };
    const update = vi.fn<SettingsPort["update"]>()
      .mockResolvedValueOnce(err({ code: "database", message: "fixture failure" }))
      .mockImplementation(async (request) => ok(mergeSettings(restored, request)));
    const { container } = render(<App
      settingsPort={{ read: async () => ok(restored), update }}
      sceneryPort={{
        read: async () => ok({ state: "ready", fileName: "fixture.png", dataUrl: "data:image/png;base64,AAAA" }),
        choose: async () => ok(null), clear: async () => ok({ state: "empty" }),
      }} />);
    const slider = await screen.findByRole("slider", { name: "背景显露" });
    await waitFor(() => expect(slider).toHaveValue("20"));
    fireEvent.change(slider, { target: { value: "100" } });
    expect(container.querySelector(".app-scenery")).toHaveStyle({ "--scenery-image-shade": "0%", "--scenery-intensity": "0.65" });
    expect(update).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "取消显露预览" }));
    expect(slider).toHaveValue("20");
    fireEvent.change(slider, { target: { value: "100" } });
    fireEvent.click(screen.getByRole("button", { name: "保存显露" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "保存显露" })).toBeEnabled());
    expect(slider).toHaveValue("100");
    fireEvent.click(screen.getByRole("button", { name: "保存显露" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "保存显露" })).toBeDisabled());
    expect(update).toHaveBeenLastCalledWith({ sceneryReveal: 100 });
    expect(slider).toHaveValue("100");
    expect(screen.getByRole("slider", { name: "背景强度" })).toHaveValue("65");
  });

  it("restores persisted preferences and applies them to scan and theme updates", async () => {
    const restored = {
      schemaVersion: 1 as const,
      themeId: "tide" as const,
      recursiveScan: false,
      includeVideo: false,
      autoplayOnLoad: false,
      sceneryIntensity: 100,
      sceneryAutoRotate: false,
    };
    const update = vi.fn<SettingsPort["update"]>(async (request) =>
      ok(mergeSettings(restored, request)),
    );
    const scanDirectory = vi.fn(
      async (
        _options: LibraryScanOptions,
        onEvent: (event: LibraryScanEvent) => void,
      ) => {
        onEvent({ event: "started", scanId: "scan-settings" });
        onEvent({
          event: "completed",
          scanId: "scan-settings",
          visited: 0,
          matched: 0,
          unreadable: 0,
        });
        return ok(emptyLibrary);
      },
    );

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch: async () => ok(emptySnapshot),
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={{ ...libraryPort(), scanDirectory }}
        libraryDirectoryPicker={{ pickDirectory: async () => ok("D:\\Music") }}
        settingsPort={{ read: async () => ok(restored), update }}
      />,
    );

    await waitFor(() =>
      expect(document.querySelector(".app-frame")).toHaveAttribute(
        "data-theme",
        "tide",
      ),
    );
    fireEvent.click(screen.getByRole("button", { name: "使用深夜主题" }));
    await waitFor(() =>
      expect(update).toHaveBeenCalledWith({ themeId: "nocturne" }),
    );

    fireEvent.click(screen.getByRole("button", { name: "曲库" }));
    fireEvent.click(await screen.findByRole("button", { name: "导入文件夹" }));
    await waitFor(() =>
      expect(scanDirectory).toHaveBeenCalledWith(
        { root: "D:\\Music", recursive: false, includeVideo: false },
        expect.any(Function),
      ),
    );
  });

  it("reads media details on demand without changing the playback queue", async () => {
    const item = {
      id: "c:\\music\\one.flac",
      path: "C:\\Music\\One.flac",
      title: "One.flac",
      kind: "audio" as const,
      durationMs: 60_000,
      available: true,
      metadataStatus: "indexed" as const,
      fastMetadata: {
        codecName: "flac",
        sampleRateHz: 48_000,
        channels: 2,
        bitsPerSample: 24,
        fileSizeBytes: 8_192,
        estimatedBitRateBps: 65_536,
      },
    };
    const dispatch = vi.fn().mockResolvedValue(ok(emptySnapshot));
    const readMediaDetails = vi.fn().mockResolvedValue(
      ok({
        mediaId: item.id,
        sourcePath: item.path,
        provider: "ffprobe" as const,
        formatName: "flac",
        formatLongName: "raw FLAC",
        durationMs: 60_000,
        sizeBytes: 8_192,
        bitRateBps: 65_536,
        streams: [],
        chapters: [],
        tags: { title: "One" },
      }),
    );

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch,
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={{
          ...libraryPort({ schemaVersion: 1, items: [item], playlists: [] }),
          readMediaDetails,
        }}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "曲库" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "更多操作 One.flac" }),
    );
    fireEvent.click(
      await screen.findByRole("button", {
        name: "查看 One.flac 的媒体详情",
      }),
    );

    expect(await screen.findByText("raw FLAC")).toBeInTheDocument();
    expect(readMediaDetails).toHaveBeenCalledWith(item.id);
    expect(dispatch).not.toHaveBeenCalled();
  });

  it("reveals a library item by stable media id without dispatching playback", async () => {
    const item = {
      id: "stable-media-id",
      path: "C:\\音乐\\One.flac",
      title: "One.flac",
      kind: "audio" as const,
      durationMs: 60_000,
      available: true,
      metadataStatus: "indexed" as const,
      fastMetadata: null,
    };
    const dispatch = vi.fn().mockResolvedValue(ok(emptySnapshot));
    const revealMedia = vi
      .fn<FileActionPort["revealMedia"]>()
      .mockResolvedValue(ok(undefined));

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch,
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={libraryPort({
          schemaVersion: 1,
          items: [item],
          playlists: [],
        })}
        fileActionPort={{ revealMedia }}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "曲库" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "更多操作 One.flac" }),
    );
    fireEvent.click(
      screen.getByRole("button", {
        name: "在资源管理器中显示 One.flac",
      }),
    );

    await waitFor(() => expect(revealMedia).toHaveBeenCalledWith(item.id));
    expect(dispatch).not.toHaveBeenCalled();
  });

  it("relocates a missing item without changing its media identity or queue position", async () => {
    const missing = {
      id: "c:\\music\\missing.flac",
      path: "C:\\Music\\Missing.flac",
      title: "Missing.flac",
      kind: "audio" as const,
      durationMs: 60_000,
      available: false,
      metadataStatus: "indexed" as const,
      fastMetadata: null,
    };
    const relocated = {
      ...missing,
      path: "D:\\Recovered\\Found.flac",
      title: "Found.flac",
      durationMs: 75_000,
      available: true,
    };
    const queued: PlaybackSnapshot = {
      ...emptySnapshot,
      generation: 1,
      sequence: 1,
      status: "paused",
      queue: [missing],
      currentIndex: 0,
      durationMs: missing.durationMs,
    };
    const refreshed: PlaybackSnapshot = {
      ...queued,
      generation: 2,
      sequence: 0,
      queue: [relocated],
      durationMs: relocated.durationMs,
    };
    const dispatch = vi.fn().mockResolvedValue(ok(refreshed));
    const relocateMedia = vi
      .fn()
      .mockResolvedValue(
        ok({ schemaVersion: 1, items: [relocated], playlists: [] }),
      );
    const pickReplacement = vi
      .fn()
      .mockResolvedValue(ok("D:\\Recovered\\Found.flac"));

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{ ...playbackReader(async () => ok(queued)), dispatch }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryRelocatePicker={{ pickReplacement }}
        libraryPort={{
          ...libraryPort({
            schemaVersion: 1,
            items: [missing],
            playlists: [],
          }),
          relocateMedia,
        }}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "曲库" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "重新定位 Missing.flac" }),
    );

    await waitFor(() =>
      expect(relocateMedia).toHaveBeenCalledWith({
        mediaId: missing.id,
        newPath: relocated.path,
      }),
    );
    expect(pickReplacement).toHaveBeenCalledWith(missing);
    expect(dispatch).toHaveBeenCalledWith({
      type: "refresh-item",
      item: {
        id: missing.id,
        path: relocated.path,
        title: relocated.title,
        kind: "audio",
        durationMs: relocated.durationMs,
      },
    });
    expect(
      await screen.findByRole("button", { name: "播放 Found.flac" }),
    ).toBeInTheDocument();
    expect(screen.queryByText("文件缺失")).toBeNull();
  });

  it("opens on-demand details for the current track from the listening console", async () => {
    const item = {
      id: "c:\\music\\one.flac",
      path: "C:\\Music\\One.flac",
      title: "One.flac",
      kind: "audio" as const,
      durationMs: 60_000,
      available: true,
      metadataStatus: "indexed" as const,
      fastMetadata: {
        codecName: "flac",
        sampleRateHz: 48_000,
        channels: 2,
        bitsPerSample: 24,
        fileSizeBytes: 8_192,
        estimatedBitRateBps: 65_536,
      },
    };
    const queued: PlaybackSnapshot = {
      ...emptySnapshot,
      generation: 1,
      sequence: 1,
      status: "paused",
      queue: [item],
      currentIndex: 0,
      durationMs: item.durationMs,
    };
    const dispatch = vi.fn().mockResolvedValue(ok(queued));
    const readMediaDetails = vi.fn().mockResolvedValue(
      ok({
        mediaId: item.id,
        sourcePath: item.path,
        provider: "ffprobe" as const,
        formatName: "flac",
        formatLongName: "raw FLAC",
        durationMs: item.durationMs,
        sizeBytes: 8_192,
        bitRateBps: 65_536,
        streams: [],
        chapters: [],
        tags: {},
      }),
    );

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{ ...playbackReader(async () => ok(queued)), dispatch }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={{
          ...libraryPort({ schemaVersion: 1, items: [item], playlists: [] }),
          readMediaDetails,
        }}
      />,
    );

    fireEvent.click(await screen.findByRole("button", { name: "媒体详情" }));

    expect(await screen.findByText("raw FLAC")).toBeInTheDocument();
    expect(readMediaDetails).toHaveBeenCalledWith(item.id);
    expect(dispatch).not.toHaveBeenCalled();
  });

  it("offers an explicit, idempotent Flutter v1 import", async () => {
    const importLegacy = vi.fn().mockResolvedValue(
      ok({
        snapshot: emptyLibrary,
        importedMedia: 2,
        importedPlaylists: 1,
        backupPath: "C:\\AppData\\migration-backups\\library.json",
        alreadyImported: false,
      }),
    );

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch: async () => ok(emptySnapshot),
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={{
          ...libraryPort(),
          readLegacyImportStatus: async () =>
            ok({ state: "ready", mediaCount: 2, playlistCount: 1 }),
          importLegacy,
        }}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "曲库" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "导入旧版数据" }),
    );

    await waitFor(() => expect(importLegacy).toHaveBeenCalledOnce());
    expect(
      await screen.findByText("旧版曲库已安全导入，不会重复添加。"),
    ).toBeInTheDocument();
  });

  it("switches to MiniPlayer without dispatching a playback command", async () => {
    const dispatch = vi.fn().mockResolvedValue(ok(emptySnapshot));
    const setMode = vi.fn(async (mode: WindowMode) =>
      ok({
        mode,
        maximized: false,
        alwaysOnTop: mode === "mini-player",
        innerWidth: mode === "mini-player" ? 420 : 1180,
        innerHeight: mode === "mini-player" ? 236 : 760,
        scaleFactor: 1.25,
      }),
    );
    const windowPort: WindowPort = {
      read: async () =>
        ok({
          mode: "main",
          maximized: false,
          alwaysOnTop: false,
          innerWidth: 1180,
          innerHeight: 760,
          scaleFactor: 1.25,
        }),
      setMode,
    };

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch,
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={libraryPort()}
        windowPort={windowPort}
      />,
    );

    const enterMini = screen.getByRole("button", {
      name: "进入迷你播放器",
    });
    await waitFor(() => expect(enterMini).toBeEnabled());
    fireEvent.click(enterMini);

    expect(await screen.findByLabelText("迷你播放器")).toBeInTheDocument();
    expect(screen.getAllByText("heni").filter((element) => !element.closest("[hidden]"))).toHaveLength(1);
    expect(screen.queryByText("Heni Mini")).toBeNull();
    expect(setMode).toHaveBeenCalledWith("mini-player");
    expect(dispatch).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole("button", { name: "返回主窗口" }));
    expect(
      await screen.findByRole("heading", { name: "开始聆听" }),
    ).toBeInTheDocument();
    expect(setMode).toHaveBeenCalledWith("main");
    expect(dispatch).not.toHaveBeenCalled();
  });

  it("presents a safe recovery action without exposing raw diagnostics", async () => {
    const privateDiagnostic =
      "access denied at C:\\Users\\listener\\Private\\song.flac";
    const pickAudioFiles = vi
      .fn<LocalMediaPickerPort["pickAudioFiles"]>()
      .mockResolvedValueOnce(
        err({ code: "path-not-authorized", message: privateDiagnostic }),
      )
      .mockResolvedValueOnce(ok([]));

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(async () => ok(emptySnapshot)),
          dispatch: async () => ok(emptySnapshot),
        }}
        localMediaPicker={{ pickAudioFiles }}
        libraryPort={libraryPort()}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "选择媒体文件" }));

    const notice = await screen.findByRole("alert", {
      name: "无法访问这个位置",
    });
    expect(notice).toHaveTextContent("请重新选择本地音频");
    expect(screen.queryByText(privateDiagnostic)).toBeNull();

    fireEvent.click(screen.getByRole("button", { name: "重新选择" }));
    await waitFor(() => expect(pickAudioFiles).toHaveBeenCalledTimes(2));
    await waitFor(() => expect(screen.queryByRole("alert")).toBeNull());
  });

  it("keeps a dismissed polling failure quiet until the connection recovers", async () => {
    const readSnapshot = vi.fn().mockResolvedValue(
      err({
        code: "transport" as const,
        message: "invoke failed at C:\\Users\\listener\\Private",
      }),
    );

    render(
      <App
        runtimeInfoPort={{
          read: async () =>
            ok({ appName: "Heni", appVersion: "0.1.0", platform: "windows" }),
        }}
        playbackPort={{
          ...playbackReader(readSnapshot),
          dispatch: async () => ok(emptySnapshot),
        }}
        localMediaPicker={{ pickAudioFiles: async () => ok([]) }}
        libraryPort={libraryPort()}
      />,
    );

    expect(
      await screen.findByRole("alert", { name: "播放操作没有完成" }),
    ).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "关闭错误提示" }));

    await act(() => new Promise((resolve) => window.setTimeout(resolve, 380)));
    expect(readSnapshot.mock.calls.length).toBeGreaterThanOrEqual(2);
    expect(screen.queryByRole("alert")).toBeNull();
  });
});
