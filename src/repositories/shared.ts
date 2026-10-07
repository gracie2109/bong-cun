// Helpers shared by every repository. Pure TS: no Vue, Pinia, router or env.
import type { PostgrestError } from "@supabase/supabase-js";

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

/** PostgREST range() bounds for a 1-based page index. */
export const pageRange = ({ pageIndex, pageSize }: PageParams) => ({
  from: (pageIndex - 1) * pageSize,
  to: pageIndex * pageSize - 1,
});

/** PostgREST filter values are comma and parenthesis separated, so these are dropped from user text. */
export const filterSafe = (text: string): string => text.replace(/[,()*%\\]/g, " ").trim();

/** Throws the PostgREST error unchanged so callers can inspect `.code`. */
export const unwrap = <T>(result: { data: T | null; error: PostgrestError | null }): T => {
  if (result.error) throw result.error;
  return result.data as T;
};

// Postgres error codes surfaced by PostgREST.
export const PG_UNIQUE_VIOLATION = "23505";
export const PG_FOREIGN_KEY_VIOLATION = "23503";
export const PG_INSUFFICIENT_PRIVILEGE = "42501";

export const hasPgCode = (error: unknown, code: string): boolean =>
  typeof error === "object" && error !== null && (error as { code?: string }).code === code;
