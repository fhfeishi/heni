import { useState } from "react";

import type {
  LibraryItem,
  LibraryPlaylist,
} from "../../contracts/library";
import { PlaylistItemsEditor } from "./PlaylistItemsEditor";
import { PlaylistMetadataForm } from "./PlaylistMetadataForm";
import { PlaylistListeningView } from "./PlaylistListeningView";

export interface PlaylistPanelProps {
  playlists: ReadonlyArray<LibraryPlaylist>;
  items: ReadonlyArray<LibraryItem>;
  busy: boolean;
  selectedPlaylistId: string | null;
  currentMediaId?: string | null;
  onPlay(playlist: LibraryPlaylist, startMediaId?: string): void;
  onCreate(name: string): Promise<boolean>;
  onUpdate(
    playlistId: string,
    name: string,
    description: string,
  ): Promise<boolean>;
  onDelete(playlistId: string): Promise<boolean>;
  onAddItems(
    playlistId: string,
    mediaIds: ReadonlyArray<string>,
  ): Promise<boolean>;
  onRemoveItems(
    playlistId: string,
    mediaIds: ReadonlyArray<string>,
  ): Promise<boolean>;
}

export const PlaylistPanel = ({
  playlists,
  items,
  busy,
  selectedPlaylistId,
  onPlay,
  currentMediaId = null,
  onCreate,
  onUpdate,
  onDelete,
  onAddItems,
  onRemoveItems,
}: PlaylistPanelProps) => {
  const [newName, setNewName] = useState("");
  const [creating, setCreating] = useState(false);
  const [metadataPlaylistId, setMetadataPlaylistId] = useState<string | null>(
    null,
  );
  const effectiveSelectedId = playlists.some(
    (playlist) => playlist.id === selectedPlaylistId,
  )
    ? selectedPlaylistId
    : (playlists[0]?.id ?? null);
  const selectedPlaylist =
    playlists.find((playlist) => playlist.id === effectiveSelectedId) ?? null;

  const create = async () => {
    const name = newName.trim();
    if (name === "") {
      return;
    }
    if (await onCreate(name)) {
      setNewName("");
      setCreating(false);
    }
  };

  return (
    <section className="playlist-panel" aria-labelledby="playlist-title" data-creating={creating}>
      <div className="playlist-heading">
        <div className="visually-hidden">
          <h2 id="playlist-title">歌单</h2>
        </div>
        {!creating ? (
          <button type="button" disabled={busy} onClick={() => setCreating(true)}>新建歌单</button>
        ) : <form
          className="playlist-create"
          onSubmit={(event) => {
            event.preventDefault();
            void create();
          }}
        >
          <label>
            <span className="visually-hidden">新歌单名称</span>
            <input
              value={newName}
              maxLength={100}
              placeholder="新歌单名称"
              disabled={busy}
              onChange={(event) => setNewName(event.currentTarget.value)}
            />
          </label>
          <button type="submit" disabled={busy || newName.trim() === ""}>
            创建歌单
          </button>
          <button type="button" disabled={busy} onClick={() => setCreating(false)}>取消新建</button>
        </form>}
      </div>

      {playlists.length === 0 ? (
        <p className="playlist-empty">创建歌单后，浏览歌单不会打断当前播放队列。</p>
      ) : (
        <div className="playlist-workspace">
          {selectedPlaylist !== null && (
            <div className="playlist-editor">
              <div className="playlist-editor__heading">
                <div>
                  <span>{selectedPlaylist.itemIds.length} 首曲目</span>
                  <h3>{selectedPlaylist.name}</h3>
                  <p>
                    {selectedPlaylist.description.trim() === ""
                      ? "尚未添加歌单说明"
                      : selectedPlaylist.description}
                  </p>
                </div>
                <button
                  type="button"
                  disabled={busy}
                  aria-expanded={metadataPlaylistId === selectedPlaylist.id}
                  onClick={() =>
                    setMetadataPlaylistId((current) =>
                      current === selectedPlaylist.id
                        ? null
                        : selectedPlaylist.id,
                    )
                  }
                >
                  {metadataPlaylistId === selectedPlaylist.id
                    ? "收起歌单信息"
                    : "编辑歌单信息"}
                </button>
              </div>
              {metadataPlaylistId === selectedPlaylist.id && (
                <PlaylistMetadataForm
                  key={`metadata-${selectedPlaylist.id}`}
                  playlist={selectedPlaylist}
                  busy={busy}
                  onUpdate={onUpdate}
                  onDelete={onDelete}
                  onCancel={() => setMetadataPlaylistId(null)}
                />
              )}
              <details key={`manage-${selectedPlaylist.id}`} className="playlist-manage">
                <summary>添加歌曲</summary>
                <PlaylistItemsEditor
                  key={`items-${selectedPlaylist.id}`}
                  playlist={selectedPlaylist}
                  playlists={playlists}
                  items={items}
                  busy={busy}
                  onAddItems={onAddItems}
                />
              </details>
              <PlaylistListeningView
                key={`listening-${selectedPlaylist.id}`}
                playlist={selectedPlaylist}
                items={items}
                busy={busy}
                onPlay={onPlay}
                currentMediaId={currentMediaId}
                onRemoveItems={onRemoveItems}
              />
            </div>
          )}
        </div>
      )}
    </section>
  );
};
