export type PageItem = number | "gap";

/** Page numbers to show: the first, the last and the neighbours of the current page, with "gap" for the rest. */
export const pageItems = (current: number, pageCount: number, neighbours = 1): PageItem[] => {
  const wanted = new Set([1, pageCount, current]);
  for (let step = 1; step <= neighbours; step++) {
    wanted.add(current - step);
    wanted.add(current + step);
  }
  const pages = [...wanted].filter((page) => page >= 1 && page <= pageCount).sort((a, b) => a - b);
  return pages.flatMap((page, index) => (index > 0 && page - (pages[index - 1] ?? 0) > 1 ? ["gap" as const, page] : [page]));
};

/** The page from the URL query: a whole number from 1, otherwise 1. */
export const pageFromQuery = (value: unknown): number => {
  const text = Array.isArray(value) ? value[0] : value;
  const page = Number(text);
  return Number.isInteger(page) && page >= 1 ? page : 1;
};
