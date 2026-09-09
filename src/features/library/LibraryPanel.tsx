import { useMemo, useState } from "react";

import type { LegacyImportStatus, LibraryItem } from "../../contracts/library";
import { LibraryItemRow } from "./LibraryItemRow";
import {
  projectLibraryItems,
  type LibraryAvailabilityFilter,
  type LibraryKindFilter,
  type LibrarySort,
} from "./libraryProjection";
import type { LibraryScanViewState } from "./useLibrary";

const readKindFilter = (value: string): LibraryKindFilter => {
  if (value === "audio" || value === "video") {
    return value;
  }
  return "all";
};

const readAvailabilityFilter = (value: string): LibraryAvailabilityFilter => {
  if (value === "available" || value === "missing") {
    return value;
  }
  return "all";
};

const readSort = (value: string): LibrarySort =>
  value === "title-desc" ? "title-desc" : "title-asc";

const scanMessage = (scan: LibraryScanViewState): string => {
  switch (scan.phase) {
    case "scanning":
      return `正在扫描：已检查 ${scan.visited} 项，匹配 ${scan.matched} 个媒体文件`;
    case "completed":
      return `扫描完成：匹配 ${scan.matched} 个媒体文件`;
    case "cancelled":
      return `扫描已取消：已保留 ${scan.matched} 个已收录文件`;
    case "finished":
      return "扫描已结束，曲库已刷新。";
    case "failed":
      return "扫描未完成，请重新导入文件夹。已经收录的音乐不会被移除。";
  }
};

export interface LibraryPanelProps {
  items: ReadonlyArray<LibraryItem>;
  loading: boolean;
  busy: boolean;
  scan: LibraryScanViewState | null;
  legacyImportStatus: LegacyImportStatus | null;
  loadingDetailsMediaId: string | null;
  relocatingMediaId: string | null;
  revealingMediaId: string | null;
  onChooseDirectory(): void;
  onChooseFiles?(): void;
  onImportLegacy(): void;
  onCancelScan(): void;
  onInspect(mediaId: string): void;
  onPlay(item: LibraryItem): void;
  onPlayNext(item: LibraryItem): void;
  onEnqueue(item: LibraryItem): void;
  onRelocate(item: LibraryItem): void;
  onReveal(item: LibraryItem): void;
}

export const LibraryPanel = ({
  items,
  loading,
  busy,
  scan,
  legacyImportStatus,
  loadingDetailsMediaId,
  relocatingMediaId,
  revealingMediaId,
  onChooseDirectory,
  onChooseFiles,
  onImportLegacy,
  onCancelScan,
  onInspect,
  onPlay,
  onPlayNext,
  onEnqueue,
  onRelocate,
  onReveal,
}: LibraryPanelProps) => {
  const [search, setSearch] = useState("");
  const [kind, setKind] = useState<LibraryKindFilter>("all");
  const [availability, setAvailability] =
    useState<LibraryAvailabilityFilter>("all");
  const [sort, setSort] = useState<LibrarySort>("title-asc");
  const visibleItems = useMemo(
    () => projectLibraryItems(items, { search, kind, availability, sort }),
    [availability, items, kind, search, sort],
  );
  const filtered =
    search.trim().length > 0 || kind !== "all" || availability !== "all";

  return (
    <section className="library-panel" aria-labelledby="library-title">
      <div className="library-heading">
        <div>
          <p className="section-label">我的音乐</p>
          <h2 id="library-title">本地曲库</h2>
        </div>
        <div className="library-heading__actions">
          <span>
            {visibleItems.length === items.length
              ? `${items.length} 项`
              : `${visibleItems.length} / ${items.length} 项`}
          </span>
          {onChooseFiles !== undefined && (
            <button type="button" disabled={busy} onClick={onChooseFiles}>
              导入音频文件
            </button>
          )}
          <button type="button" disabled={busy} onClick={onChooseDirectory}>
            导入文件夹
          </button>
        </div>
      </div>

      {legacyImportStatus?.state === "ready" && (
        <div className="legacy-import" aria-live="polite">
          <span>
            发现旧版 heni 曲库：{legacyImportStatus.mediaCount} 个媒体文件、
            {legacyImportStatus.playlistCount}{" "}
            个歌单。导入前会备份，原数据不会改动。
          </span>
          <button type="button" disabled={busy} onClick={onImportLegacy}>
            导入旧版数据
          </button>
        </div>
      )}

      {legacyImportStatus?.state === "imported" && (
        <p className="legacy-import legacy-import--complete" aria-live="polite">
          旧版曲库已安全导入，不会重复添加。
        </p>
      )}

      {scan !== null && (
        <div className="scan-status" aria-live="polite">
          <span>{scanMessage(scan)}</span>
          {scan.phase === "scanning" && (
            <button type="button" onClick={onCancelScan}>
              取消扫描
            </button>
          )}
        </div>
      )}

      {items.length > 0 && (
        <div className="library-toolbar" aria-label="曲库筛选">
          <label className="library-search">
            <span>搜索</span>
            <input
              type="search"
              value={search}
              placeholder="标题、路径或编码"
              onChange={(event) => setSearch(event.currentTarget.value)}
            />
          </label>
          <label>
            <span>媒体类型</span>
            <select
              value={kind}
              onChange={(event) =>
                setKind(readKindFilter(event.currentTarget.value))
              }
            >
              <option value="all">全部类型</option>
              <option value="audio">音频</option>
              <option value="video">视频</option>
            </select>
          </label>
          <label>
            <span>文件状态</span>
            <select
              value={availability}
              onChange={(event) =>
                setAvailability(
                  readAvailabilityFilter(event.currentTarget.value),
                )
              }
            >
              <option value="all">全部状态</option>
              <option value="available">可用</option>
              <option value="missing">缺失</option>
            </select>
          </label>
          <label>
            <span>排序</span>
            <select
              value={sort}
              onChange={(event) => setSort(readSort(event.currentTarget.value))}
            >
              <option value="title-asc">标题 A–Z</option>
              <option value="title-desc">标题 Z–A</option>
            </select>
          </label>
        </div>
      )}

      {loading ? (
        <p className="library-empty">正在读取本地曲库…</p>
      ) : items.length === 0 ? (
        <p className="library-empty">
          还没有收录音乐。选择音频或导入文件夹后，歌曲会出现在这里。
        </p>
      ) : visibleItems.length === 0 ? (
        <div className="library-empty">
          <div>
            <strong>没有符合筛选条件的媒体</strong>
            <button
              type="button"
              onClick={() => {
                setSearch("");
                setKind("all");
                setAvailability("all");
              }}
            >
              清除筛选
            </button>
          </div>
        </div>
      ) : (
        <ul
          className="library-list"
          aria-label={filtered ? "筛选结果" : "曲库媒体"}
        >
          {visibleItems.map((item) => (
            <LibraryItemRow
              key={item.id}
              item={item}
              busy={busy}
              loadingDetails={loadingDetailsMediaId === item.id}
              relocating={relocatingMediaId === item.id}
              revealing={revealingMediaId === item.id}
              onInspect={() => onInspect(item.id)}
              onPlay={() => onPlay(item)}
              onPlayNext={() => onPlayNext(item)}
              onEnqueue={() => onEnqueue(item)}
              onRelocate={() => onRelocate(item)}
              onReveal={() => onReveal(item)}
            />
          ))}
        </ul>
      )}
    </section>
  );
};
