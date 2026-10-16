// Translates database errors into app error codes. Pure TS: no Vue, Pinia, router or env.

import { AppError, type AppErrorCode } from "@bongcun/core/shared";

// Postgres error codes surfaced by PostgREST.
export const PG_UNIQUE_VIOLATION = "23505";
export const PG_FOREIGN_KEY_VIOLATION = "23503";
export const PG_INSUFFICIENT_PRIVILEGE = "42501";

const PG_TO_APP: Record<string, AppErrorCode> = {
  [PG_UNIQUE_VIOLATION]: "conflict",
  [PG_FOREIGN_KEY_VIOLATION]: "in_use",
  [PG_INSUFFICIENT_PRIVILEGE]: "forbidden",
};

/** The app error a Postgres error stands for, or null when it is not one of the shared cases. */
export const toAppError = (error: unknown): AppError | null => {
  if (error instanceof AppError) return error;
  const code = typeof error === "object" && error !== null ? (error as { code?: string }).code : undefined;
  const appCode = code ? PG_TO_APP[code] : undefined;
  return appCode ? new AppError(appCode, error) : null;
};
