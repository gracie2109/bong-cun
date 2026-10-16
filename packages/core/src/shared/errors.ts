/** Failures every screen handles the same way, whatever backend raised them. */
export type AppErrorCode = "forbidden" | "conflict" | "in_use";

/**
 * `C` widens the codes for a module that names its own business failures (the `hint`s the database
 * raises: `no_open_shift`, `out_of_stock`...), see `pos/errors.ts` and `shop/errors.ts`.
 */
export class AppError<C extends string = AppErrorCode> extends Error {
  constructor(
    public readonly code: C,
    cause?: unknown
  ) {
    super(code, { cause });
    this.name = "AppError";
  }
}
