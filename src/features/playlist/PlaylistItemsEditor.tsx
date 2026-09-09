import { useMemo, useRef, useState } from "react";
import type { LibraryItem, LibraryPlaylist } from "../../contracts/library";
import { projectPlaylistCandidates } from "./playlistProjection";

export interface PlaylistItemsEditorProps {
  playlist: LibraryPlaylist;
  playlists: ReadonlyArray<LibraryPlaylist>;
  items: ReadonlyArray<LibraryItem>;
  busy: boolean;
  onAddItems(playlistId: string, mediaIds: ReadonlyArray<string>): Promise<boolean>;
}

/** Copy references from a source; never remove membership from that source. */
export const PlaylistItemsEditor = ({ playlist, playlists, items, busy, onAddItems }: PlaylistItemsEditorProps) => {
  const [sourceId, setSourceId] = useState("");
  const [search, setSearch] = useState("");
  const [selection, setSelection] = useState<ReadonlyArray<string>>([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(false);
  const pending = useRef(false);
  const candidates = useMemo(() => {
    const source = playlists.find((candidate) => candidate.id === sourceId);
    const byId = new Map(items.map((item) => [item.id, item]));
    const sourceItems = sourceId === "" ? items : (source?.itemIds ?? []).flatMap((id) => {
      const item = byId.get(id);
      return item === undefined ? [] : [item];
    });
    return projectPlaylistCandidates(playlist, sourceItems, search);
  }, [playlist, playlists, items, sourceId, search]);
  const selectedIds = candidates.filter((item) => selection.includes(item.id)).map((item) => item.id);
  const add = async () => {
    if (busy || pending.current || selectedIds.length === 0) return;
    pending.current = true;
    setSaving(true);
    setError(false);
    try {
      if (await onAddItems(playlist.id, selectedIds)) setSelection([]);
      else setError(true);
    } catch { setError(true); }
    finally { pending.current = false; setSaving(false); }
  };
  return (
    <div className="playlist-columns playlist-columns--add">
      <fieldset disabled={busy || saving}>
        <legend>添加到此歌单</legend>
        <label>来源
          <select aria-label="添加歌曲来源" value={sourceId} onChange={(event) => {
            setSourceId(event.currentTarget.value); setSelection([]);
          }}>
            <option value="">整个曲库</option>
            {playlists.filter((source) => source.id !== playlist.id).map((source) => (
              <option key={source.id} value={source.id}>{source.name}</option>
            ))}
          </select>
        </label>
        <label className="playlist-list-search">
          <span className="visually-hidden">搜索可加入曲目</span>
          <input type="search" value={search} placeholder="搜索可加入曲目" onChange={(event) => {
            setSearch(event.currentTarget.value); setSelection([]);
          }} />
        </label>
        {candidates.length === 0 ? <p>此来源中没有可加入的匹配曲目，已在歌单中的歌曲不会重复加入。</p> : <>
          <label><input type="checkbox" aria-label="全选可加入曲目" checked={selectedIds.length === candidates.length}
            onChange={(event) => setSelection(event.currentTarget.checked ? candidates.map((item) => item.id) : [])} />全选</label>
          <ul>{candidates.map((item) => <li key={item.id}><label>
            <input type="checkbox" aria-label={item.title} checked={selectedIds.includes(item.id)}
              onChange={(event) => setSelection(event.currentTarget.checked ? [...selectedIds, item.id] : selectedIds.filter((id) => id !== item.id))} />
            <span><strong>{item.title}</strong><small>{item.path}</small></span>
          </label></li>)}</ul>
        </>}
        <button type="button" disabled={selectedIds.length === 0} onClick={() => void add()}>加入所选（{selectedIds.length}）</button>
        {error && <p role="status">未能添加歌曲，所选项目已保留，请重试。</p>}
      </fieldset>
    </div>
  );
};
