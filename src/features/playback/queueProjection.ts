import type { PlaybackItem } from "../../contracts/playback";

export interface QueueProjectionRow {
  item: PlaybackItem;
  queueIndex: number;
  isCurrent: boolean;
  isNext: boolean;
}

const searchableText = (item: PlaybackItem): string =>
  `${item.title}\n${item.path}`.toLocaleLowerCase("zh-CN");

export const projectQueueRows = (
  queue: ReadonlyArray<PlaybackItem>,
  currentIndex: number | null,
  search: string,
  nextIndex: number | null = currentIndex === null ? null : currentIndex + 1,
): ReadonlyArray<Readonly<QueueProjectionRow>> => {
  const query = search.trim().toLocaleLowerCase("zh-CN");
  return queue.flatMap((item, queueIndex) => {
    if (query.length > 0 && !searchableText(item).includes(query)) {
      return [];
    }
    return [
      {
        item,
        queueIndex,
        isCurrent: queueIndex === currentIndex,
        isNext: nextIndex !== null && queueIndex === nextIndex,
      },
    ];
  });
};
