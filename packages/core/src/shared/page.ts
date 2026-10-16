export type Page<T> = { rows: T[]; total: number };

export type PageParams = { pageIndex: number; pageSize: number };

/**
 * Copies the two page fields. Callers pass a reactive object that a table
 * component mutates in place; reading each field here is what lets Vue track it.
 */
export const toPage = (page: PageParams): PageParams => ({
  pageIndex: page.pageIndex,
  pageSize: page.pageSize,
});
