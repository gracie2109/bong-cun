/** Failures every screen handles the same way, whatever backend raised them. */
export type AppErrorCode = "forbidden" | "conflict" | "in_use";

export class AppError extends Error {
  constructor(
    public readonly code: AppErrorCode,
    cause?: unknown
  ) {
    super(code, { cause });
    this.name = "AppError";
  }
}
