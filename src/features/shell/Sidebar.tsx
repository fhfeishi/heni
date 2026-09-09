import { NavigationIcon } from "./NavigationIcon";
import type { LibraryPlaylist } from "../../contracts/library";
import { appViewLabels, type AppView } from "./appView";

export interface SidebarProps {
  playlists?: ReadonlyArray<LibraryPlaylist> | undefined;
  selectedPlaylistId?: string | null | undefined;
  onSelectPlaylist?: ((id: string) => void) | undefined;
  activeView: AppView;
  libraryCount: number;
  playlistCount: number;
  queueCount: number;
  onSelect(view: AppView): void;
}

const countFor = (
  view: AppView,
  counts: Readonly<Record<"library" | "playlists" | "queue", number>>,
): number | null => {
  if (view === "now-playing") {
    return null;
  }
  return counts[view];
};

export const Sidebar = ({
  playlists = [],
  selectedPlaylistId,
  onSelectPlaylist,
  activeView,
  libraryCount,
  playlistCount,
  queueCount,
  onSelect,
}: SidebarProps) => {
  const effectivePlaylistId = playlists.some((playlist) => playlist.id === selectedPlaylistId)
    ? selectedPlaylistId : (playlists[0]?.id ?? null);
  const counts = {
    library: libraryCount,
    playlists: playlistCount,
    queue: queueCount,
  };
  const views: ReadonlyArray<AppView> = [
    "now-playing",
    "library",
    "playlists",
    "queue",
  ];

  return (
    <aside className="app-sidebar">
      <nav aria-label="主导航">
        {views.map((view) => {
          const count = countFor(view, counts);
          return (
            <button
              key={view}
              type="button"
              className={
                activeView === view
                  ? "sidebar-link sidebar-link--active"
                  : "sidebar-link"
              }
              aria-label={appViewLabels[view]}
              aria-current={activeView === view ? "page" : undefined}
              onClick={() => onSelect(view)}
            >
              <span className="sidebar-link__icon">
                <NavigationIcon view={view} />
              </span>
              <span className="sidebar-link__label">{appViewLabels[view]}</span>
              {count !== null && (
                <span className="sidebar-link__count" aria-hidden="true">
                  {count}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {playlists.length > 0 && onSelectPlaylist !== undefined && (
        <nav className="sidebar-playlists" aria-label="我的歌单">
          <span className="sidebar-playlists__heading">我的歌单</span>
          {playlists.map((playlist) => (
            <button type="button" key={playlist.id} title={playlist.name}
              aria-current={activeView === "playlists" && playlist.id === effectivePlaylistId ? "page" : undefined}
              onClick={() => onSelectPlaylist(playlist.id)}>
              <span>{playlist.name}</span>
              <small>{playlist.itemIds.length}</small>
            </button>
          ))}
        </nav>
      )}

      <div className="sidebar-note">
        <span>安心听歌</span>
        <p>音乐文件始终保留在本机。</p>
      </div>
    </aside>
  );
};
