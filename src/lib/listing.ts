/** Value of the "no filter" option in a list's select filters. */
export const FILTER_ALL = "all";

/** Wait after the last keystroke before searching on the server. */
export const SEARCH_DEBOUNCE_MS = 500;

/** Shorter wait for lists that filter small sets and should feel immediate. */
export const SEARCH_DEBOUNCE_FAST_MS = 300;

/** Rows per page offered by the paged tables in the admin. */
export const TABLE_PAGE_SIZES = [10, 20, 50, 100];

const PAGE_WINDOW_SIBLINGS = 1;

/** Page buttons to show: first, last, the pages around the current one, and "gap" markers between. */
export const pageWindow = (page: number, pageCount: number): (number | "gap-left" | "gap-right")[] => {
  const from = Math.max(2, page - PAGE_WINDOW_SIBLINGS);
  const to = Math.min(pageCount - 1, page + PAGE_WINDOW_SIBLINGS);
  const items: (number | "gap-left" | "gap-right")[] = [1];
  if (from > 2) items.push("gap-left");
  for (let i = from; i <= to; i++) items.push(i);
  if (to < pageCount - 1) items.push("gap-right");
  if (pageCount > 1) items.push(pageCount);
  return items;
};
