import { createRoot } from "react-dom/client";

import type { LibraryItem } from "../../contracts/library";
import { LibraryPanel } from "../../features/library/LibraryPanel";
import { PlaybackBar } from "../../features/playback/PlaybackBar";
import { AppFrame } from "../../features/shell/AppFrame";
import "../../styles/global.css";

const libraryItems: ReadonlyArray<LibraryItem> = Array.from(
  { length: 36 },
  (_, index) => ({
    id: `visual-media-${index}`,
    path:
      index === 0
        ? "C:\\用户\\本地音乐\\一段非常长的中文目录名称用于验证最小窗口不会横向溢出\\录音室母带最终版本.flac"
        : `C:\\音乐\\专辑 ${index % 6}\\Track ${index}.${index % 7 === 0 ? "mp4" : "flac"}`,
    title:
      index === 0
        ? "一首标题很长但不应挤压操作按钮的本地音乐作品.flac"
        : `Track ${index}`,
    kind: index % 7 === 0 ? ("video" as const) : ("audio" as const),
    durationMs: index % 7 === 0 ? null : 180_000,
    available: index % 11 !== 0,
    metadataStatus:
      index % 7 === 0 ? ("pending" as const) : ("indexed" as const),
    fastMetadata:
      index % 7 === 0
        ? null
        : {
            codecName: "flac",
            sampleRateHz: 48_000,
            channels: 2,
            bitsPerSample: 24,
            fileSizeBytes: 31_457_280,
            estimatedBitRateBps: 1_398_000,
          },
  }),
);

const root = document.querySelector<HTMLElement>("#root");
if (root === null) {
  throw new Error("Visual fixture root was not found.");
}

createRoot(root).render(
  <AppFrame
    activeView="library"
    bootState={{ status: "ready" }}
    libraryCount={libraryItems.length}
    playlistCount={3}
    queueCount={2}
    themeId="studio"
    windowMode="main"
    windowControlsAvailable={true}
    windowBusy={false}
    onSelectView={() => undefined}
    onSelectTheme={() => undefined}
    onToggleWindowMode={() => undefined}
    miniPlayer={null}
    playbackBar={
      <PlaybackBar
        clockSample={null}
        snapshot={null}
        currentItem={null}
        busy={false}
        onDispatch={async () => false}
        onOpenQueue={() => undefined}
      />
    }
  >
    <LibraryPanel
      items={libraryItems}
      loading={false}
      busy={false}
      scan={null}
      legacyImportStatus={null}
      loadingDetailsMediaId={null}
      relocatingMediaId={null}
      revealingMediaId={null}
      onChooseDirectory={() => undefined}
      onImportLegacy={() => undefined}
      onCancelScan={() => undefined}
      onInspect={() => undefined}
      onPlay={() => undefined}
      onPlayNext={() => undefined}
      onEnqueue={() => undefined}
      onRelocate={() => undefined}
      onReveal={() => undefined}
    />
  </AppFrame>,
);
