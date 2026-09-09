import type { LibraryItem } from "../../contracts/library";

export type LibraryKindFilter = "all" | "audio" | "video";
export type LibraryAvailabilityFilter = "all" | "available" | "missing";
export type LibrarySort = "title-asc" | "title-desc";

export interface LibraryProjectionOptions {
  search: string;
  kind: LibraryKindFilter;
  availability: LibraryAvailabilityFilter;
  sort: LibrarySort;
}

const searchableText = (item: LibraryItem): string =>
  [item.title, item.path, item.fastMetadata?.codecName ?? ""]
    .join("\n")
    .toLocaleLowerCase("zh-CN");

const compareTitle = (left: LibraryItem, right: LibraryItem): number => {
  const titleOrder = left.title.localeCompare(right.title, "zh-CN", {
    numeric: true,
    sensitivity: "base",
  });
  return titleOrder === 0 ? left.id.localeCompare(right.id) : titleOrder;
};

export const projectLibraryItems = (
  items: ReadonlyArray<LibraryItem>,
  options: LibraryProjectionOptions,
): ReadonlyArray<LibraryItem> => {
  const query = options.search.trim().toLocaleLowerCase("zh-CN");
  const projected = items.filter((item) => {
    if (options.kind !== "all" && item.kind !== options.kind) {
      return false;
    }
    if (options.availability === "available" && !item.available) {
      return false;
    }
    if (options.availability === "missing" && item.available) {
      return false;
    }
    return query.length === 0 || searchableText(item).includes(query);
  });

  projected.sort((left, right) => {
    const order = compareTitle(left, right);
    return options.sort === "title-asc" ? order : -order;
  });
  return projected;
};
