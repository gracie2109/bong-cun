import type { Ref } from "vue";
import type { WidgetState } from "./types";

export type QueryStatus = {
  isPending: boolean;
  isError: boolean;
  /** True while the data shown belongs to the previous key (another branch or range). */
  isPlaceholderData?: boolean;
  error?: unknown;
};

const FORBIDDEN_CODES = ["42501", "forbidden"];

export const isForbiddenError = (error: unknown): boolean => {
  const code = typeof error === "object" && error !== null ? (error as { code?: unknown }).code : undefined;
  return typeof code === "string" && FORBIDDEN_CODES.includes(code);
};

/**
 * The single place that decides what a widget shows. Data of another branch is never shown while the
 * new one loads, and a failed read never falls back to stale numbers.
 */
export const resolveWidgetState = (input: {
  allowed: boolean;
  needsBranch?: boolean;
  query: QueryStatus;
  isEmpty: boolean;
}): WidgetState => {
  const { allowed, needsBranch, query, isEmpty } = input;
  if (!allowed) return "hidden";
  if (needsBranch) return "needsBranch";
  if (query.isError) return isForbiddenError(query.error) ? "forbidden" : "error";
  if (query.isPending || query.isPlaceholderData) return "loading";
  return isEmpty ? "empty" : "ready";
};

/** The fields of a vue-query result the state needs, read once (they are refs). */
export const statusOf = (query: {
  isPending: Ref<boolean>;
  isError: Ref<boolean>;
  isPlaceholderData?: Ref<boolean>;
  error?: Ref<unknown>;
}): QueryStatus => ({
  isPending: query.isPending.value,
  isError: query.isError.value,
  isPlaceholderData: query.isPlaceholderData?.value,
  error: query.error?.value,
});
