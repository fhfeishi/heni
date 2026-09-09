import { useState } from "react";
import { createRoot } from "react-dom/client";

import type { LibraryItem, LibraryPlaylist } from "../../contracts/library";
import type { PlaybackSnapshot } from "../../contracts/playback";
import type { WindowMode } from "../../contracts/window";
import { MiniPlayer } from "../../features/playback/MiniPlayer";
import { PlaybackBar } from "../../features/playback/PlaybackBar";
import { QueueView } from "../../features/playback/QueueView";
import { NowPlayingView } from "../../features/player/NowPlayingView";
import { PlaylistPanel } from "../../features/playlist/PlaylistPanel";
import { AppFrame } from "../../features/shell/AppFrame";
import type { AppView } from "../../features/shell/appView";
import type { HeniThemeId } from "../../features/shell/theme";
import "../../styles/global.css";

const libraryItems: ReadonlyArray<LibraryItem> = Array.from(
  { length: 60 },
  (_, index) => ({
    id: `visual-media-${index}`,
    path:
      index === 0
        ? "C:\\用户\\本地音乐\\一个很长的歌单验证目录\\录音室母带最终混音版本.flac"
        : `D:\\Music\\Album ${index % 9}\\Track ${String(index + 1).padStart(2, "0")}.flac`,
    title:
      index === 0
        ? "一首很长的标题也不应破坏歌单和队列布局.flac"
        : `Track ${String(index + 1).padStart(2, "0")}`,
    kind: "audio" as const,
    durationMs: 150_000 + index * 1_000,
    available: index % 13 !== 0,
    metadataStatus: "indexed" as const,
    fastMetadata: {
      codecName: "flac",
      sampleRateHz: 48_000,
      channels: 2,
      bitsPerSample: 24,
      fileSizeBytes: 28_000_000,
      estimatedBitRateBps: 1_400_000,
    },
  }),
);

const playlists: ReadonlyArray<LibraryPlaylist> = [
  {
    id: "commute",
    name: "通勤与清晨",
    description: "适合早晚通勤、不打断当前播放会话的本地收藏。",
    itemIds: libraryItems.slice(0, 20).map((item) => item.id),
  },
  {
    id: "long-name",
    name: "一个很长但仍然必须保持导航清晰的歌单名称",
    description: "布局压力测试",
    itemIds: libraryItems.slice(18, 33).map((item) => item.id),
  },
  ...Array.from({ length: 6 }, (_, index) => ({
    id: `playlist-${index}`,
    name: `本地歌单 ${index + 1}`,
    description: "",
    itemIds: libraryItems
      .slice(index * 3, index * 3 + 8)
      .map((item) => item.id),
  })),
];

const queue = libraryItems
  .slice(0, 24)
  .map(({ id, path, title, kind, durationMs }) => ({
    id,
    path,
    title,
    kind,
    durationMs,
  }));

const snapshot: PlaybackSnapshot = {
  generation: 4,
  sequence: 28,
  status: "playing",
  queue,
  currentIndex: 5,
  positionMs: 63_000,
  durationMs: queue[5]?.durationMs ?? null,
  volume: 74,
  muted: false,
  repeatMode: "all",
  shuffle: false,
};

export const SessionWorkspacesPreview = () => {
  const [activeView, setActiveView] = useState<AppView>("queue");
  const [selectedPlaylistId, setSelectedPlaylistId] = useState<string | null>(null);
  const [themeId, setThemeId] = useState<HeniThemeId>("studio");
  const [windowMode, setWindowMode] = useState<WindowMode>("main");
  const currentItem = queue[snapshot.currentIndex ?? 0] ?? null;
  const mainView =
    activeView === "now-playing" ? (
      <NowPlayingView
        currentItem={currentItem}
        currentLibraryItem={libraryItems[snapshot.currentIndex ?? 0] ?? null}
        nextItem={queue[(snapshot.currentIndex ?? 0) + 1] ?? null}
        status={snapshot.status}
        picking={false}
        busy={false}
        loadingDetails={false}
        onChooseFiles={() => undefined}
        onChooseDirectory={() => undefined}
        onOpenLibrary={() => undefined}
        onInspectDetails={() => undefined}
      />
    ) : activeView === "playlists" ? (
      <PlaylistPanel
        selectedPlaylistId={selectedPlaylistId}
        playlists={playlists}
        onPlay={() => setActiveView("now-playing")}
        items={libraryItems}
        busy={false}
        onCreate={async () => true}
        onUpdate={async () => true}
        onDelete={async () => true}
        onAddItems={async () => true}
        onRemoveItems={async () => true}
      />
    ) : (
      <QueueView
        snapshot={snapshot}
        busy={false}
        onDispatch={() => undefined}
      />
    );

  return (
    <AppFrame
      playlists={playlists}
      selectedPlaylistId={selectedPlaylistId}
      onSelectPlaylist={(id) => { setSelectedPlaylistId(id); setActiveView("playlists"); }}
      activeView={activeView}
      bootState={{ status: "ready" }}
      libraryCount={libraryItems.length}
      playlistCount={playlists.length}
      queueCount={queue.length}
      themeId={themeId}
      windowMode={windowMode}
      windowControlsAvailable={true}
      windowBusy={false}
      onSelectView={(view) => {
        if (
          view === "queue" ||
          view === "playlists" ||
          view === "now-playing"
        ) {
          setActiveView(view);
        }
      }}
      onSelectTheme={setThemeId}
      onToggleWindowMode={() =>
        setWindowMode((mode) => (mode === "main" ? "mini-player" : "main"))
      }
      miniPlayer={
        <MiniPlayer
          clockSample={null}
          snapshot={snapshot}
          currentItem={currentItem}
          busy={false}
          onDispatch={async () => false}
          onOpenQueue={() => {
            setWindowMode("main");
            setActiveView("queue");
          }}
        />
      }
      playbackBar={
        <PlaybackBar
          clockSample={null}
          snapshot={snapshot}
          currentItem={currentItem}
          busy={false}
          onDispatch={async () => false}
          onOpenQueue={() => setActiveView("queue")}
        />
      }
    >
      {mainView}
    </AppFrame>
  );
};

const root = document.querySelector<HTMLElement>("#root");
if (root === null) {
  throw new Error("Visual fixture root was not found.");
}

createRoot(root).render(<SessionWorkspacesPreview />);
