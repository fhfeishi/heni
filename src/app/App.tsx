import { useRef, useState } from "react";

import type { FileActionPort } from "../contracts/fileAction";
import type {
  LibraryDirectoryPickerPort,
  LibraryItem,
  LibraryPlaylist,
  LibraryPort,
  LibraryRelocatePickerPort,
} from "../contracts/library";
import type { LocalMediaPickerPort } from "../contracts/localMedia";
import type { PlaybackPort } from "../contracts/playback";
import type { RuntimeInfoPort } from "../contracts/runtime";
import type { SettingsPort } from "../contracts/settings";
import type { SceneryPort } from "../contracts/scenery";
import type { WindowPort } from "../contracts/window";
import { LibraryPanel } from "../features/library/LibraryPanel";
import { MediaDetailsPanel } from "../features/library/MediaDetailsPanel";
import { useLibrary } from "../features/library/useLibrary";
import { useFileAction } from "../features/library/useFileAction";
import { useMediaDetails } from "../features/library/useMediaDetails";
import { NowPlayingView } from "../features/player/NowPlayingView";
import { MiniPlayer } from "../features/playback/MiniPlayer";
import { PlaybackBar } from "../features/playback/PlaybackBar";
import { VideoStage } from "../features/playback/VideoStage";
import { isPlayableMedia } from "../features/playback/playableMedia";
import { QueueView } from "../features/playback/QueueView";
import { usePlayback } from "../features/playback/usePlayback";
import { PlaylistPanel } from "../features/playlist/PlaylistPanel";
import { useRuntimeInfo } from "../features/runtime/useRuntimeInfo";
import { useSettings } from "../features/settings/useSettings";
import { SceneryControl } from "../features/scenery/SceneryControl";
import { SceneryIntensityControl } from "../features/scenery/SceneryIntensityControl";
import { SceneryRevealControl } from "../features/scenery/SceneryRevealControl";
import { ListeningViewSwitch } from "../features/shell/ListeningViewSwitch";
import { GlassControl } from "../features/settings/GlassControl";
import { defaultGlassSettings, type GlassSettings } from "../contracts/settings";
import { useScenery } from "../features/scenery/useScenery";
import { AppFrame } from "../features/shell/AppFrame";
import { AppNotice } from "../features/shell/AppNotice";
import {
  presentAppError,
  type AppErrorContext,
  type AppRecoveryAction,
} from "../features/shell/appErrorPresentation";
import type { AppView } from "../features/shell/appView";
import { RetainedView } from "../features/shell/RetainedView";
import { useWindowMode } from "../features/shell/useWindowMode";
import { tauriLocalMediaPicker } from "../infrastructure/tauri/localMediaPicker";
import { tauriFileActionPort } from "../infrastructure/tauri/fileActionPort";
import { tauriLibraryDirectoryPicker } from "../infrastructure/tauri/libraryDirectoryPicker";
import { tauriLibraryPort } from "../infrastructure/tauri/libraryPort";
import { tauriLibraryRelocatePicker } from "../infrastructure/tauri/libraryRelocatePicker";
import { tauriPlaybackPort } from "../infrastructure/tauri/playbackPort";
import { tauriRuntimeInfoPort } from "../infrastructure/tauri/runtimeInfoPort";
import { tauriSettingsPort } from "../infrastructure/tauri/settingsPort";
import { tauriSceneryPort } from "../infrastructure/tauri/sceneryPort";
import { tauriWindowPort } from "../infrastructure/tauri/windowPort";
import { useLocalImportWorkflows } from "./workflows/useLocalImportWorkflows";
import { projectAppBootState } from "./boot/projectAppBootState";

export interface AppProps {
  runtimeInfoPort?: RuntimeInfoPort;
  playbackPort?: PlaybackPort;
  localMediaPicker?: LocalMediaPickerPort;
  libraryPort?: LibraryPort;
  libraryDirectoryPicker?: LibraryDirectoryPickerPort;
  libraryRelocatePicker?: LibraryRelocatePickerPort;
  fileActionPort?: FileActionPort;
  settingsPort?: SettingsPort;
  sceneryPort?: SceneryPort;
  windowPort?: WindowPort;
}

const toPlaybackItem = ({
  id,
  path,
  title,
  kind,
  durationMs,
}: LibraryItem) => ({ id, path, title, kind, durationMs });

export const App = ({
  runtimeInfoPort = tauriRuntimeInfoPort,
  playbackPort = tauriPlaybackPort,
  localMediaPicker = tauriLocalMediaPicker,
  libraryPort = tauriLibraryPort,
  libraryDirectoryPicker = tauriLibraryDirectoryPicker,
  libraryRelocatePicker = tauriLibraryRelocatePicker,
  fileActionPort = tauriFileActionPort,
  settingsPort = tauriSettingsPort,
  sceneryPort = tauriSceneryPort,
  windowPort = tauriWindowPort,
}: AppProps) => {
  const runtime = useRuntimeInfo(runtimeInfoPort);
  const playback = usePlayback(playbackPort);
  const library = useLibrary(libraryPort);
  const mediaDetails = useMediaDetails(libraryPort);
  const fileAction = useFileAction(fileActionPort);
  const settings = useSettings(settingsPort);
  const scenery = useScenery(sceneryPort, !settings.loading && settings.snapshot.sceneryAutoRotate);
  const [sceneryIntensityDraft, setSceneryIntensityDraft] = useState<number | null>(null);
  const [sceneryRevealDraft, setSceneryRevealDraft] = useState<number | null>(null);
  const savedSceneryReveal = settings.snapshot.sceneryReveal ?? 0;
  const [glassDraft, setGlassDraft] = useState<GlassSettings | null>(null);
  const savedGlass = settings.snapshot.glass ?? defaultGlassSettings;
  const windowMode = useWindowMode(windowPort);
  const [activeView, setActiveView] = useState<AppView>("now-playing");
  const [selectedPlaylistId, setSelectedPlaylistId] = useState<string | null>(null);
  const [browseView, setBrowseView] = useState<Exclude<AppView, "now-playing">>("library");
  const [playlistRequest, setPlaylistRequest] = useState<{
    playlist: LibraryPlaylist;
    startMediaId?: string;
    generation: number;
    sequence: number;
  } | null>(null);
  const playlistSubmitting = useRef(false);
  const navigationRevision = useRef(0);
  const [relocatingMediaId, setRelocatingMediaId] = useState<string | null>(
    null,
  );
  const [pickerError, setPickerError] = useState<AppErrorContext | null>(null);
  const imports = useLocalImportWorkflows({
    localMediaPicker,
    libraryDirectoryPicker,
    settings: settings.snapshot,
    importFiles: library.importFiles,
    scanDirectory: library.scanDirectory,
    clearLibraryError: library.clearError,
    onFilesImported: () => {
      setBrowseView("library");
      setActiveView("library");
    },
    onDirectorySelected: () => setActiveView("library"),
  });
  const bootState = projectAppBootState({
    runtime,
    playback: {
      loading: playback.loading,
      available: playback.snapshot !== null,
    },
    library: {
      loading: library.loading,
      available: library.snapshot !== null,
    },
  });
  const isBrowserPreview =
    bootState.status === "degraded" && bootState.reason === "browser-preview";
  const snapshot = playback.snapshot;
  const currentItem =
    snapshot?.currentIndex === null || snapshot?.currentIndex === undefined
      ? null
      : (snapshot.queue[snapshot.currentIndex] ?? null);
  const nextItem =
    snapshot?.currentIndex === null || snapshot?.currentIndex === undefined
      ? null
      : (snapshot.queue[snapshot.currentIndex + 1] ?? null);
  const currentLibraryItem =
    currentItem === null
      ? null
      : (library.snapshot?.items.find((item) => item.id === currentItem.id) ??
        null);
  const visibleError: AppErrorContext | null =
    imports.error !== null
      ? imports.error
      : pickerError !== null
        ? pickerError
        : mediaDetails.error !== null
          ? { source: "media-details", error: mediaDetails.error }
          : fileAction.error !== null
            ? { source: "file-action", error: fileAction.error }
            : library.error !== null && !isBrowserPreview
              ? { source: "library", error: library.error }
              : playback.error !== null && !isBrowserPreview
                ? { source: "playback", error: playback.error }
                : windowMode.error !== null
                  ? { source: "window", error: windowMode.error }
                  : null;

  const selectView = (view: AppView) => {
    navigationRevision.current += 1;
    setPlaylistRequest(null);
    if (view !== "now-playing") setBrowseView(view);
    if (view !== "library") {
      mediaDetails.close();
    }
    setActiveView(view);
  };

  const chooseFiles = () => {
    setPickerError(null);
    void imports.chooseFiles();
  };

  const chooseDirectory = () => {
    setPickerError(null);
    void imports.chooseDirectory();
  };

  const playLibraryItem = (item: LibraryItem) => {
    setBrowseView("library");
    const queue = (library.snapshot?.items ?? [])
      .filter(isPlayableMedia)
      .map(toPlaybackItem);
    const currentIndex = queue.findIndex(
      (candidate) => candidate.id === item.id,
    );
    if (currentIndex < 0) {
      return;
    }
    void playback.dispatch({
      type: "replace-queue",
      queue,
      currentIndex,
      autoplay: true,
    });
    setActiveView("now-playing");
  };

  const relocateLibraryItem = async (item: LibraryItem) => {
    setRelocatingMediaId(item.id);
    setPickerError(null);
    imports.clearError();
    library.clearError();
    playback.clearError();
    const selected = await libraryRelocatePicker.pickReplacement(item);
    if (!selected.ok) {
      setRelocatingMediaId(null);
      setPickerError({ source: "relocate-picker", error: selected.error });
      return;
    }
    if (selected.value === null) {
      setRelocatingMediaId(null);
      return;
    }
    const relocated = await library.relocateMedia(item.id, selected.value);
    if (
      relocated !== null &&
      snapshot?.queue.some((candidate) => candidate.id === relocated.id)
    ) {
      await playback.dispatch({
        type: "refresh-item",
        item: toPlaybackItem(relocated),
      });
    }
    setRelocatingMediaId(null);
  };

  const playPlaylist = async (playlist: LibraryPlaylist, startMediaId?: string) => {
    if (playback.busy || playlistSubmitting.current) return;
    const byId = new Map((library.snapshot?.items ?? []).map((item) => [item.id, item]));
    const queue = playlist.itemIds.flatMap((id) => {
      const item = byId.get(id);
      return item !== undefined && isPlayableMedia(item) ? [toPlaybackItem(item)] : [];
    });
    if (queue.length === 0) return;
    const currentIndex = startMediaId === undefined ? 0 : queue.findIndex((item) => item.id === startMediaId);
    if (currentIndex < 0) return;
    playlistSubmitting.current = true;
    setPlaylistRequest(null);
    const revision = navigationRevision.current;
    try {
      if (await playback.dispatch({ type: "replace-queue", queue, currentIndex, autoplay: true })
        && navigationRevision.current === revision) {
        setBrowseView("playlists");
        setActiveView("now-playing");
      }
    } finally {
      playlistSubmitting.current = false;
    }
  };

  // A changed queue or playback command invalidates a previous replacement consent.
  const confirmedPlaylist = playlistRequest !== null
    && playlistRequest.generation === snapshot?.generation
    && playlistRequest.sequence === snapshot.sequence
    ? playlistRequest.playlist : null;

  const requestPlaylistPlayback = (playlist: LibraryPlaylist, startMediaId?: string) => {
    if (snapshot !== null && snapshot.queue.length > 0) {
      setPlaylistRequest({
        playlist,
        ...(startMediaId === undefined ? {} : { startMediaId }),
        generation: snapshot.generation,
        sequence: snapshot.sequence,
      });
    } else {
      void playPlaylist(playlist, startMediaId);
    }
  };

  const renderView = (view: AppView) => {
    if (view === "library") {
      return (
        <LibraryPanel
          items={library.snapshot?.items ?? []}
          loading={library.loading}
          busy={
            library.busy ||
            playback.busy ||
            imports.pickingDirectory ||
            imports.pickingFiles ||
            fileAction.busyMediaId !== null ||
            settings.busy
          }
          scan={library.scan}
          legacyImportStatus={library.legacyImportStatus}
          loadingDetailsMediaId={mediaDetails.loadingMediaId}
          relocatingMediaId={relocatingMediaId}
          revealingMediaId={fileAction.busyMediaId}
          onChooseDirectory={chooseDirectory}
          onChooseFiles={chooseFiles}
          onImportLegacy={() => void library.importLegacy()}
          onCancelScan={() => void library.cancelScan()}
          onInspect={(mediaId) => void mediaDetails.inspect(mediaId)}
          onPlay={playLibraryItem}
          onPlayNext={(item) =>
            void playback.dispatch({
              type: "play-next",
              items: [toPlaybackItem(item)],
            })
          }
          onEnqueue={(item) =>
            void playback.dispatch({
              type: "enqueue",
              items: [toPlaybackItem(item)],
            })
          }
          onRelocate={(item) => void relocateLibraryItem(item)}
          onReveal={(item) => void fileAction.revealMedia(item.id)}
        />
      );
    }
    if (view === "playlists") {
      return (
        <PlaylistPanel
          currentMediaId={currentItem?.id ?? null}
          selectedPlaylistId={selectedPlaylistId}
          playlists={library.snapshot?.playlists ?? []}
          items={library.snapshot?.items ?? []}
          busy={library.busy || playback.busy}
          onPlay={requestPlaylistPlayback}
          onCreate={library.createPlaylist}
          onUpdate={library.updatePlaylist}
          onDelete={library.deletePlaylist}
          onAddItems={library.addPlaylistItems}
          onRemoveItems={library.removePlaylistItems}
        />
      );
    }
    if (view === "queue") {
      return (
        <QueueView
          snapshot={snapshot}
          busy={playback.busy}
          onDispatch={(command) => void playback.dispatch(command)}
        />
      );
    }
    return (
      <NowPlayingView
        currentItem={currentItem}
        currentLibraryItem={currentLibraryItem}
        nextItem={nextItem}
        status={snapshot?.status ?? null}
        picking={imports.pickingFiles}
        busy={
          imports.pickingFiles ||
          imports.pickingDirectory ||
          playback.busy ||
          library.busy ||
          settings.busy
        }
        loadingDetails={mediaDetails.loadingMediaId === currentLibraryItem?.id}
        onChooseFiles={chooseFiles}
        onChooseDirectory={chooseDirectory}
        onOpenLibrary={() => setActiveView("library")}
        onInspectDetails={() => {
          if (currentLibraryItem !== null) {
            void mediaDetails.inspect(currentLibraryItem.id);
          }
        }}
      />
    );
  };

  const clearVisibleErrors = () => {
    setPickerError(null);
    imports.clearError();
    mediaDetails.close();
    fileAction.clearError();
    settings.clearError();
    library.clearError();
    playback.clearError();
    windowMode.clearError();
  };

  const recoverFromError = (action: AppRecoveryAction) => {
    clearVisibleErrors();
    if (action === "open-library") {
      setActiveView("library");
      return;
    }
    if (action === "choose-directory") {
      chooseDirectory();
      return;
    }
    chooseFiles();
  };

  const notice =
    visibleError === null ? undefined : (
      <AppNotice
        presentation={presentAppError(visibleError)}
        onAction={recoverFromError}
        onClose={clearVisibleErrors}
      />
    );

  return (
    <AppFrame
      playlists={library.snapshot?.playlists ?? []}
      selectedPlaylistId={selectedPlaylistId}
      onSelectPlaylist={(id) => {
        setSelectedPlaylistId(id);
        selectView("playlists");
      }}
      activeView={activeView}
      bootState={bootState}
      libraryCount={library.snapshot?.items.length ?? 0}
      playlistCount={library.snapshot?.playlists.length ?? 0}
      queueCount={snapshot?.queue.length ?? 0}
      themeId={settings.snapshot.themeId}
      viewControls={<ListeningViewSwitch stage={activeView === "now-playing"}
        onBrowse={() => selectView(browseView)} onStage={() => selectView("now-playing")} />}
      onChooseScenery={() => void scenery.choose()}
      sceneryBusy={scenery.loading || scenery.busy}
      sceneryAvailable={!isBrowserPreview}
      sceneryImageUrl={scenery.imageUrl}
      sceneryIntensity={sceneryIntensityDraft ?? settings.snapshot.sceneryIntensity}
      sceneryReveal={sceneryRevealDraft ?? savedSceneryReveal}
      videoVisible={activeView === "now-playing" && currentItem?.kind === "video"}
      glass={glassDraft ?? savedGlass}
      onSceneryImageError={scenery.reportImageFailure}
      sceneryIssue={
        !isBrowserPreview &&
        (scenery.error !== null || scenery.snapshot.state === "unavailable")
      }
      sceneryControls={
        <>
        <GlassControl
          value={glassDraft ?? savedGlass}
          dirty={glassDraft !== null && (glassDraft.material !== savedGlass.material || glassDraft.transparency !== savedGlass.transparency || glassDraft.fog !== savedGlass.fog)}
          disabled={settings.loading || settings.busy}
          onChange={setGlassDraft}
          onCancel={() => setGlassDraft(null)}
          onSave={() => {
            if (glassDraft === null) return;
            void settings.update({ glass: glassDraft }).then((saved) => {
              if (saved) setGlassDraft(null);
            });
          }}
        />
        <SceneryControl
          snapshot={scenery.snapshot}
          loading={scenery.loading}
          busy={scenery.busy}
          error={scenery.error}
          preview={isBrowserPreview}
          onChoose={() => void scenery.choose()}
          onClear={() => void scenery.clear()}
          canStep={scenery.canStep}
          onNext={() => void scenery.next()}
          onPrevious={() => void scenery.previous()}
          autoRotate={settings.snapshot.sceneryAutoRotate}
          rotationBusy={settings.loading || settings.busy}
          onAutoRotateChange={(sceneryAutoRotate) => void settings.update({ sceneryAutoRotate })}
        />
        <SceneryIntensityControl
          value={sceneryIntensityDraft ?? settings.snapshot.sceneryIntensity}
          dirty={sceneryIntensityDraft !== null && sceneryIntensityDraft !== settings.snapshot.sceneryIntensity}
          disabled={settings.loading || settings.busy || scenery.busy || scenery.snapshot.state !== "ready"}
          onChange={setSceneryIntensityDraft}
          onCancel={() => setSceneryIntensityDraft(null)}
          onSave={() => {
            if (sceneryIntensityDraft === null) return;
            void settings.update({ sceneryIntensity: sceneryIntensityDraft }).then((saved) => {
              if (saved) setSceneryIntensityDraft(null);
            });
          }}
        />
        <SceneryRevealControl
          value={sceneryRevealDraft ?? savedSceneryReveal}
          dirty={sceneryRevealDraft !== null && sceneryRevealDraft !== savedSceneryReveal}
          disabled={settings.loading || settings.busy || scenery.busy || scenery.snapshot.state !== "ready"}
          onChange={setSceneryRevealDraft}
          onCancel={() => setSceneryRevealDraft(null)}
          onSave={() => {
            if (sceneryRevealDraft === null) return;
            void settings.update({ sceneryReveal: sceneryRevealDraft }).then((saved) => {
              if (saved) setSceneryRevealDraft(null);
            });
          }}
        />
        </>
      }
      windowMode={windowMode.mode}
      windowControlsAvailable={windowMode.available}
      windowBusy={windowMode.busy}
      onSelectView={selectView}
      onSelectTheme={(themeId) => void settings.update({ themeId })}
      preferences={settings.snapshot}
      settingsBusy={settings.busy}
      settingsError={
        settings.error === null || isBrowserPreview
          ? undefined
          : "设置暂未保存，当前偏好保持不变；播放和曲库功能不受影响。"
      }
      onUpdateSettings={(request) => void settings.update(request)}
      onToggleWindowMode={() =>
        void windowMode.setMode(
          windowMode.mode === "main" ? "mini-player" : "main",
        )
      }
      overlay={
        mediaDetails.details === null ? undefined : (
          <MediaDetailsPanel
            details={mediaDetails.details}
            onClose={mediaDetails.close}
          />
        )
      }
      notice={notice}
      playbackBar={
        <PlaybackBar
          snapshot={snapshot}
          clockSample={playback.clockSample}
          currentItem={currentItem}
          busy={playback.busy}
          onDispatch={playback.dispatch}
          onOpenQueue={() => selectView("queue")}
        />
      }
      miniPlayer={
        <MiniPlayer
          sceneryImageUrl={scenery.imageUrl}
          snapshot={snapshot}
          clockSample={playback.clockSample}
          currentItem={currentItem}
          busy={playback.busy}
          onDispatch={playback.dispatch}
          onOpenQueue={() => {
            void windowMode.setMode("main").then((restored) => {
              if (restored) {
                selectView("queue");
              }
            });
          }}
        />
      }
    >
      {confirmedPlaylist !== null && (
        <div className="playlist-replace-confirmation" role="alert">
          <p>播放「{confirmedPlaylist.name}」会替换当前队列，并从{playlistRequest?.startMediaId === undefined ? "第一首可播放歌曲" : "所选曲目"}开始。</p>
          <button type="button" disabled={playback.busy}
            onClick={() => void playPlaylist(confirmedPlaylist, playlistRequest?.startMediaId)}>替换队列并播放</button>
          <button type="button" onClick={() => setPlaylistRequest(null)}>保留当前队列</button>
        </div>
      )}
      {(["library", "playlists", "queue"] as const).map((view) => (
        <RetainedView key={view} active={activeView === view}>
          {renderView(view)}
        </RetainedView>
      ))}
      <VideoStage visible={activeView === "now-playing" && currentItem?.kind === "video"} title={currentItem?.title ?? ""} />
      {activeView === "now-playing" && currentItem?.kind !== "video" && renderView("now-playing")}
    </AppFrame>
  );
};
