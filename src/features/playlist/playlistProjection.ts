import type {
  LibraryItem,
  LibraryPlaylist,
} from "../../contracts/library";

export interface PlaylistMemberRow {
  mediaId: string;
  playlistIndex: number;
  item: LibraryItem | null;
}

const searchableItemText = (item: LibraryItem): string =>
  `${item.title}\n${item.path}`.toLocaleLowerCase("zh-CN");

export const projectPlaylistMembers = (
  playlist: LibraryPlaylist,
  items: ReadonlyArray<LibraryItem>,
  search: string,
): ReadonlyArray<Readonly<PlaylistMemberRow>> => {
  const itemById = new Map(items.map((item) => [item.id, item]));
  const query = search.trim().toLocaleLowerCase("zh-CN");

  return playlist.itemIds.flatMap((mediaId, playlistIndex) => {
    const item = itemById.get(mediaId) ?? null;
    const searchableText = item === null ? mediaId.toLocaleLowerCase("zh-CN") : searchableItemText(item);
    if (query.length > 0 && !searchableText.includes(query)) {
      return [];
    }
    return [{ mediaId, playlistIndex, item }];
  });
};

export const projectPlaylistCandidates = (
  playlist: LibraryPlaylist,
  items: ReadonlyArray<LibraryItem>,
  search: string,
): ReadonlyArray<LibraryItem> => {
  const selectedIds = new Set(playlist.itemIds);
  const query = search.trim().toLocaleLowerCase("zh-CN");

  return items.filter(
    (item) =>
      !selectedIds.has(item.id) &&
      (query.length === 0 || searchableItemText(item).includes(query)),
  );
};
