// Helpers shared by every repository. Pure TS: no Vue, Pinia, router or env.
export { toPage, type Page, type PageParams } from "@bongcun/core/shared";
export * from "./errors";
import type { PostgrestError } from "@supabase/supabase-js";
import type { ZodType } from "zod";
import type { PageParams } from "@bongcun/core/shared";

/** PostgREST range() bounds for a 1-based page index. */
export const pageRange = ({ pageIndex, pageSize }: PageParams) => ({
  from: (pageIndex - 1) * pageSize,
  to: pageIndex * pageSize - 1,
});

/** PostgREST filter values are comma and parenthesis separated, so these are dropped from user text. */
export const filterSafe = (text: string): string => text.replace(/[,()*%\\]/g, " ").trim();

/** An `or()` condition matching any of the columns against typed text; null when nothing usable was typed. */
export const searchOr = (columns: string[], text: string): string | null => {
  const term = filterSafe(text);
  return term ? columns.map((column) => `${column}.ilike.%${term}%`).join(",") : null;
};

/** Throws the PostgREST error unchanged so callers can inspect `.code`. */
export const unwrap = <T>(result: { data: T | null; error: PostgrestError | null }): T => {
  if (result.error) throw result.error;
  return result.data as T;
};

/**
 * Checks the `jsonb` an RPC returned against the shape the code expects. A renamed or missing key
 * then fails here, naming the RPC and the key, instead of showing `undefined` on a screen.
 */
export const parseRpc = <T>(rpc: string, schema: ZodType<T>, data: unknown): T => {
  const result = schema.safeParse(data);
  if (result.success) return result.data;
  const issue = result.error.issues[0];
  throw new Error(`${rpc} returned an unexpected shape at "${issue?.path.join(".") ?? ""}": ${issue?.message ?? "invalid"}`);
};
