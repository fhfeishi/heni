import { useEffect, useId, useMemo, useRef, useState, type ReactNode } from "react";
import { InterfaceIcon } from "../../components/InterfaceIcon";

import type { LibraryItem, LibraryPlaylist } from "../../contracts/library";
import { projectPlaylistMembers } from "./playlistProjection";
import { isPlayableMedia } from "../playback/playableMedia";

interface PlaylistListeningViewProps {
  playlist: LibraryPlaylist;
  items: ReadonlyArray<LibraryItem>;
  busy: boolean;
  addControls: ReactNode;
  currentMediaId: string | null;
  onRemoveItems(playlistId: string, mediaIds: ReadonlyArray<string>): Promise<boolean>;
  onPlay(playlist: LibraryPlaylist, startMediaId?: string): void;
}

const presentTrackStatus = (item: LibraryItem | null): string => {
  if (item === null || !item.available) return "文件不可用";
  if (!isPlayableMedia(item)) return "暂不支持此容器";
  if (item.kind === "video" && item.durationMs === null) return "视频";
  if (item.durationMs === null) return "—";
  const seconds = Math.floor(item.durationMs / 1_000);
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
};

/** Browsing/search is a projection; playing always uses the complete playlist. */
export const PlaylistListeningView = ({
  playlist,
  items,
  busy,
  addControls,
  onPlay,
  currentMediaId,
  onRemoveItems,
}: PlaylistListeningViewProps) => {
  const [search, setSearch] = useState("");
  const [adding, setAdding] = useState(false);
  const [selecting, setSelecting] = useState(false);
  const selectButton = useRef<HTMLButtonElement>(null);
  const addRegionId = useId();
  const addButton = useRef<HTMLButtonElement>(null);
  const [selection, setSelection] = useState<ReadonlyArray<string>>([]);
  const [removing, setRemoving] = useState(false);
  const [error, setError] = useState(false);
  const removingRef = useRef(false);
  const currentRow = useRef<HTMLLIElement>(null);
  const [locateRequest, setLocateRequest] = useState(0);
  useEffect(() => {
    if (locateRequest === 0) return;
    currentRow.current?.scrollIntoView?.({ block: "center", behavior: "auto" });
    currentRow.current?.focus({ preventScroll: true });
  }, [locateRequest]);
  const selectedIds = selection.filter((id) => playlist.itemIds.includes(id));
  const remove = async (ids: ReadonlyArray<string>) => {
    if (busy || removingRef.current || ids.length === 0) return;
    removingRef.current = true;
    setRemoving(true);
    setError(false);
    try {
      if (await onRemoveItems(playlist.id, ids)) setSelection([]);
      else setError(true);
    } catch { setError(true); }
    finally { removingRef.current = false; setRemoving(false); }
  };
  const rows = useMemo(
    () => projectPlaylistMembers(playlist, items, search),
    [playlist, items, search],
  );
  const playableCount = useMemo(
    () => projectPlaylistMembers(playlist, items, "").filter(
      ({ item }) => item !== null && isPlayableMedia(item),
    ).length,
    [playlist, items],
  );
  const skipped = playlist.itemIds.length - playableCount;

  return (
    <div className="playlist-listening" data-selecting={selecting} onKeyDown={(event) => {
      if (event.key === "Escape" && selecting && !removing) {
        setSelecting(false); setSelection([]); selectButton.current?.focus();
      }
    }}>
      <div className="playlist-listening__actions">
        <button
          type="button"
          className="playlist-action playlist-action--play"
          aria-label="播放歌单"
          disabled={busy || removing || playableCount === 0}
          onClick={() => onPlay(playlist)}
        >
          <InterfaceIcon name="play" /><span>播放</span>
        </button>
        <button ref={addButton} type="button" className="playlist-action" aria-expanded={adding}
          aria-controls={addRegionId} disabled={removing}
          onClick={() => { setAdding((value) => !value); setSelecting(false); setSelection([]); }}>
          <InterfaceIcon name={adding ? "close" : "add"} /><span>添加歌曲</span>
        </button>
        <button ref={selectButton} type="button" className="playlist-action" aria-pressed={selecting}
          disabled={removing || playlist.itemIds.length === 0}
          onClick={() => { setSelecting(!selecting); setSelection([]); setAdding(false); }}>
          <InterfaceIcon name={selecting ? "close" : "check"} /><span>{selecting ? "完成多选" : "多选"}</span>
        </button>
        <button type="button" className="playlist-action playlist-action--icon" aria-label="定位当前播放歌曲"
          title={currentMediaId === null || !playlist.itemIds.includes(currentMediaId) ? "当前歌曲不在此歌单" : "定位当前播放歌曲"}
          disabled={currentMediaId === null || !playlist.itemIds.includes(currentMediaId)}
          onClick={() => { setSearch(""); setSelection([]); setLocateRequest((value) => value + 1); }}>
          <InterfaceIcon name="locate" />
        </button>
        <label className="playlist-list-search">
          <span className="visually-hidden">搜索此歌单</span>
          <input
            type="search"
            value={search}
            placeholder="在歌单中查找"
            onChange={(event) => { setSearch(event.currentTarget.value); setSelection([]); }}
          />
        </label>
      </div>
      <div id={addRegionId} className="playlist-add-region" hidden={!adding}
        onKeyDown={(event) => {
          if (event.key === "Escape") {
            event.stopPropagation(); setAdding(false); addButton.current?.focus();
          }
        }}>{addControls}</div>
      {error && <p role="status">曲目未移除，所选项目已保留，请重试。</p>}
      {selecting && rows.length > 0 && <div className="playlist-selection-bar"><label className="playlist-select-all"><input type="checkbox" aria-label="全选当前搜索结果"
        ref={(element) => { if (element !== null) element.indeterminate = selectedIds.length > 0 && selectedIds.length < rows.length; }}
        disabled={busy || removing} checked={rows.every(({ mediaId }) => selectedIds.includes(mediaId))}
        onChange={(event) => setSelection(event.currentTarget.checked ? rows.map(({ mediaId }) => mediaId) : [])} />
        {selectedIds.length > 0 ? `已选 ${selectedIds.length} 首` : "全选"}</label>
        {selectedIds.length > 0 && <>
          <button type="button" className="playlist-action playlist-action--remove"
            aria-label={`移除所选（${selectedIds.length}）`} title="只移出此歌单，不删除文件"
            disabled={busy || removing} onClick={() => void remove(selectedIds)}>
            <InterfaceIcon name="subtract" /><span>{removing ? "移除中…" : "移出歌单"}</span>
          </button>
          <button type="button" className="playlist-action playlist-action--icon" aria-label="取消选择" title="取消选择"
            disabled={removing} onClick={() => setSelection([])}><InterfaceIcon name="close" /></button>
        </>}
      </div>}
      {skipped > 0 && (
        <p className="playlist-listening__hint">
          播放时将跳过 {skipped} 项不可用文件或暂不支持的容器。
        </p>
      )}
      {rows.length === 0 ? (
        <p className="playlist-empty">{search.trim() === ""
          ? "还没有歌曲，点击添加歌曲，从曲库或其他歌单加入。"
          : "没有匹配的歌曲；播放歌单仍按完整歌单顺序。"}</p>
      ) : (
        <ol className="playlist-track-list" aria-label="歌单歌曲">
          {rows.map(({ mediaId, playlistIndex, item }) => (
            <li key={`${playlistIndex}:${mediaId}`} tabIndex={-1}
              ref={mediaId === currentMediaId ? currentRow : undefined}
              aria-current={mediaId === currentMediaId ? "true" : undefined}
              onDoubleClick={(event) => {
                if ((event.target as HTMLElement).closest("button, input")) return;
                if (!selecting && !busy && !removing && item !== null && isPlayableMedia(item)) onPlay(playlist, mediaId);
              }}>
              {selecting && <input type="checkbox" aria-label={`选择 ${item?.title ?? mediaId}`} disabled={busy || removing}
                checked={selectedIds.includes(mediaId)} onChange={(event) => setSelection(event.currentTarget.checked
                  ? [...selectedIds, mediaId] : selectedIds.filter((id) => id !== mediaId))} />}
              <span className="playlist-track-list__lead">
                <span className="playlist-track-list__index">{playlistIndex + 1}</span>
                <button type="button" className="playlist-row-play" aria-label={`播放 ${item?.title ?? mediaId}`} title="从此曲开始播放"
                  disabled={busy || removing || item === null || !isPlayableMedia(item)} onClick={() => onPlay(playlist, mediaId)}><InterfaceIcon name="play" /></button>
              </span>
              <strong>{item?.title ?? "曲库中已缺失"}</strong>
              <span>{presentTrackStatus(item)}</span>
              <button type="button" className="playlist-row-remove" aria-label={`移除 ${item?.title ?? mediaId}`} title="只移出此歌单，不删除文件"
                disabled={busy || removing} onClick={() => void remove([mediaId])}><InterfaceIcon name="subtract" /></button>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
};
