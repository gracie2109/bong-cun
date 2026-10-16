// Translates database errors into app error codes. Pure TS: no Vue, Pinia, router or env.

import { AppError, type AppErrorCode } from "@bongcun/core/shared";
import { posErrorHint, type PosErrorHint } from "@bongcun/core/pos";
import { shopErrorHint, type ShopErrorHint } from "@bongcun/core/shop";

// Postgres error codes surfaced by PostgREST.
export const PG_UNIQUE_VIOLATION = "23505";
export const PG_FOREIGN_KEY_VIOLATION = "23503";
export const PG_INSUFFICIENT_PRIVILEGE = "42501";

/** Every code an error leaving this package can carry. */
export type DbErrorCode = AppErrorCode | PosErrorHint | ShopErrorHint;

const PG_TO_APP: Record<string, AppErrorCode> = {
  [PG_UNIQUE_VIOLATION]: "conflict",
  [PG_FOREIGN_KEY_VIOLATION]: "in_use",
  [PG_INSUFFICIENT_PRIVILEGE]: "forbidden",
};

/**
 * The app error a database error stands for, or null when it is not a known case. A Postgres code
 * wins; otherwise the `hint` the function raised (`no_open_shift`, `out_of_stock`...) becomes the code.
 */
export const toAppError = (error: unknown): AppError<DbErrorCode> | null => {
  if (error instanceof AppError) return error as AppError<DbErrorCode>;
  const code = typeof error === "object" && error !== null ? (error as { code?: string }).code : undefined;
  const appCode: DbErrorCode | undefined = (code ? PG_TO_APP[code] : undefined) ?? posErrorHint(error) ?? shopErrorHint(error) ?? undefined;
  return appCode ? new AppError(appCode, error) : null;
};
