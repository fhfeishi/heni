import { useEffect, useRef, useState, type ReactNode } from "react";
import { InterfaceIcon } from "../../components/InterfaceIcon";
import { defaultGlassSettings, type GlassSettings } from "../../contracts/settings";
import { glassStyle } from "./glass";
import { sceneryImmersion } from "./sceneryPresentation";
import type { LibraryPlaylist } from "../../contracts/library";

import type {
  SettingsSnapshot,
  SettingsUpdate,
} from "../../contracts/settings";
import type { WindowMode } from "../../contracts/window";
import type { AppBootState } from "../runtime/appBootState";
import { PreferencesControl } from "../settings/PreferencesControl";
import { SceneryBackdrop } from "./SceneryBackdrop";
import { WindowChrome } from "./WindowChrome";
import { Sidebar } from "./Sidebar";
import { appViewLabels, type AppView } from "./appView";
import type { HeniThemeId } from "./theme";

export interface AppFrameProps {
  playlists?: ReadonlyArray<LibraryPlaylist>;
  selectedPlaylistId?: string | null;
  onSelectPlaylist?(id: string): void;
  activeView: AppView;
  bootState: AppBootState;
  libraryCount: number;
  playlistCount: number;
  queueCount: number;
  themeId: HeniThemeId;
  windowMode: WindowMode;
  windowControlsAvailable: boolean;
  windowBusy: boolean;
  onSelectView(view: AppView): void;
  onSelectTheme(themeId: HeniThemeId): void;
  onToggleWindowMode(): void;
  preferences?: SettingsSnapshot;
  settingsBusy?: boolean;
  settingsError?: string | undefined;
  onUpdateSettings?(request: SettingsUpdate): void;
  children: ReactNode;
  playbackBar: ReactNode;
  miniPlayer: ReactNode;
  sceneryImageUrl?: string | null;
  sceneryIntensity?: number;
  sceneryReveal?: number;
  videoVisible?: boolean;
  glass?: GlassSettings;
  sceneryControls?: ReactNode;
  viewControls?: ReactNode;
  onChooseScenery?(): void;
  sceneryBusy?: boolean;
  sceneryAvailable?: boolean;
  sceneryIssue?: boolean;
  onSceneryImageError?(imageUrl: string): void;
  overlay?: ReactNode;
  notice?: ReactNode;
}

const bootCopy: Readonly<Record<AppBootState["status"], string>> = {
  booting: "正在准备播放器",
  ready: "播放器已就绪",
  degraded: "部分功能暂不可用",
  blocked: "播放器暂不可用",
};

const presentBootState = (state: AppBootState): string =>
  state.status === "degraded" && state.reason === "browser-preview"
    ? "界面预览模式"
    : bootCopy[state.status];

export const AppFrame = ({
  playlists,
  selectedPlaylistId,
  onSelectPlaylist,
  activeView,
  bootState,
  libraryCount,
  playlistCount,
  queueCount,
  themeId,
  windowMode,
  windowControlsAvailable,
  windowBusy,
  onSelectView,
  onToggleWindowMode,
  preferences,
  settingsBusy = false,
  settingsError,
  onUpdateSettings,
  children,
  playbackBar,
  miniPlayer,
  sceneryImageUrl,
  sceneryIntensity = 100,
  sceneryReveal = 0,
  videoVisible = false,
  glass = defaultGlassSettings,
  sceneryControls,
  viewControls,
  onChooseScenery,
  sceneryBusy = false,
  sceneryAvailable = true,
  sceneryIssue = false,
  onSceneryImageError,
  overlay,
  notice,
}: AppFrameProps) => {
  const bootStatusCopy = presentBootState(bootState);
  const mini = windowMode === "mini-player";
  const [panelsPinned, setPanelsPinned] = useState(false);
  const [loadedScenery, setLoadedScenery] = useState<string | null>(null);
  const [contentRestored, setContentRestored] = useState(false);
  const immersion = !mini && !videoVisible && sceneryIntensity > 0 && sceneryImageUrl != null
    && loadedScenery === sceneryImageUrl ? sceneryImmersion(sceneryReveal) : 0;
  const concealContent = immersion > 0 && !contentRestored;
  const mainContent = useRef<HTMLElement>(null);
  const restoreContentButton = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    if (concealContent && mainContent.current?.contains(document.activeElement)) {
      restoreContentButton.current?.focus();
    }
  }, [concealContent]);
  return (
    <div className="app-frame" data-theme={themeId} data-window-mode={windowMode}
      data-edge-panels={panelsPinned ? "pinned" : "auto"} style={glassStyle(glass)}>
      <WindowChrome mini={mini} onRestoreMain={onToggleWindowMode} busy={windowBusy} />
      <SceneryBackdrop
        key={themeId}
        activeView={mini ? "now-playing" : activeView}
        imageUrl={sceneryImageUrl ?? null}
        intensity={sceneryIntensity}
        reveal={concealContent ? sceneryReveal : Math.min(sceneryReveal, 100)}
        onImageLoad={setLoadedScenery}
        onImageError={(url) => { setLoadedScenery(null); onSceneryImageError?.(url); }}
      />
      {mini && <>
        <header className="mini-player-chrome">
          <span className="brand-wordmark brand-wordmark--mini">heni</span>
          <div>
            <strong>迷你播放器</strong>
            <span>随时聆听</span>
          </div>
          <button
            type="button"
            className="window-mode-button"
            aria-label="返回主窗口"
            title={windowBusy ? "正在切换窗口" : "返回主窗口"}
            aria-busy={windowBusy}
            disabled={windowBusy}
            onClick={onToggleWindowMode}
          >
            <InterfaceIcon name="expand" />
          </button>
        </header>
        {notice}
        {miniPlayer}
      </>}
      <div className="app-main-shell" hidden={mini} inert={mini}>
        <header className="app-topbar">
          <button
            type="button"
            className="brand-button"
            aria-label="转到正在播放"
            onClick={() => onSelectView("now-playing")}
          >
            <span className="brand-wordmark">heni</span>
          </button>

          <div className="topbar-navigation">
            <h1 className="sr-only">{appViewLabels[activeView]}</h1>
            {viewControls}
          </div>

          <div className="topbar-actions">
            {immersion > 0 && <button ref={restoreContentButton} type="button" className="window-mode-button"
              aria-label={concealContent ? "显示内容" : "恢复背景沉浸"}
              title={concealContent ? "显示内容并恢复列表操作" : "恢复背景沉浸"}
              aria-pressed={contentRestored} onClick={() => setContentRestored((value) => !value)}>
              <InterfaceIcon name="songs" />
            </button>}
            {onChooseScenery !== undefined && (
              <button type="button" className="window-mode-button" aria-label="更换背景图片"
                title={sceneryAvailable ? "更换背景图片" : "背景图片需要桌面环境"}
                disabled={!sceneryAvailable || sceneryBusy} aria-busy={sceneryBusy}
                onClick={onChooseScenery}>
                <InterfaceIcon name="image" />
              </button>
            )}
            <button type="button" className="window-mode-button" aria-label="固定工具面板"
              aria-pressed={panelsPinned} title={panelsPinned ? "改为靠近边缘展开" : "固定工具面板"}
              onClick={() => setPanelsPinned((pinned) => !pinned)}>
              <InterfaceIcon name="pin" />
            </button>
            <button
              type="button"
              className="window-mode-button"
              aria-label="进入迷你播放器"
              aria-busy={windowBusy}
              title={
                windowControlsAvailable
                  ? "切换为置顶迷你播放器"
                  : "当前运行环境不支持窗口切换"
              }
              disabled={!windowControlsAvailable || windowBusy}
              onClick={onToggleWindowMode}
            >
              <InterfaceIcon name="mini" />
            </button>
            {preferences !== undefined && onUpdateSettings !== undefined && (
              <PreferencesControl
                settings={preferences}
                busy={settingsBusy}
                errorMessage={settingsError}
                onUpdate={onUpdateSettings}
                appearanceControls={sceneryControls}
                appearanceIssue={sceneryIssue}
              />
            )}
            <div
              className={`runtime-status runtime-status--${bootState.status}`}
              role="status"
              aria-label={bootStatusCopy}
            >
              <span className="runtime-status__indicator" aria-hidden="true" />
              <span className="runtime-status__copy" aria-hidden="true">
                {bootStatusCopy}
              </span>
            </div>
          </div>
        </header>

        <div className="app-workspace">
          <Sidebar
            playlists={playlists}
            selectedPlaylistId={selectedPlaylistId}
            onSelectPlaylist={onSelectPlaylist}
            activeView={activeView}
            libraryCount={libraryCount}
            playlistCount={playlistCount}
            queueCount={queueCount}
            onSelect={onSelectView}
          />
          <main ref={mainContent} className="main-view" id="main-content" inert={concealContent}
            aria-hidden={concealContent || undefined} style={{ opacity: concealContent ? 1 - immersion : 1 }}>
            {children}
          </main>
        </div>

        {overlay}
        {notice}
        {!mini && playbackBar}
      </div>
    </div>
  );
};
