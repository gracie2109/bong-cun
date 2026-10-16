import { EXPORT_PAGE_SIZE } from "./columns";

export type FetchedPage<T> = { rows: T[]; total: number };

export type FetchAllResult<T> = { rows: T[]; total: number; truncated: boolean };

type FetchAllOptions = {
  pageSize?: number;
  /** Most rows to keep; later pages are not asked for. */
  cap: number;
  onProgress?: (done: number, total: number) => void;
};

/** Reads a list page by page (1-based page index) until `total` or `cap` rows are in. */
export const fetchAllPages = async <T>(
  fetchPage: (pageIndex: number, pageSize: number) => Promise<FetchedPage<T>>,
  { pageSize = EXPORT_PAGE_SIZE, cap, onProgress }: FetchAllOptions,
): Promise<FetchAllResult<T>> => {
  const rows: T[] = [];
  let total = Infinity;
  for (let pageIndex = 1; rows.length < Math.min(total, cap); pageIndex++) {
    const page = await fetchPage(pageIndex, pageSize);
    total = page.total;
    if (page.rows.length === 0) break;
    rows.push(...page.rows);
    onProgress?.(Math.min(rows.length, cap), Math.min(total, cap));
  }
  const known = Number.isFinite(total) ? total : rows.length;
  return { rows: rows.slice(0, cap), total: known, truncated: known > cap };
};
