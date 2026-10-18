import type { H3Event } from "h3";

/**
 * Runs a public read and hides what went wrong behind it: the caller gets a plain 502, the
 * database error stays in the server log. Errors already shaped by h3 (bad query, 404) pass through.
 */
export const publicRead = async <T>(event: H3Event, read: () => Promise<T>): Promise<T> => {
  try {
    return await read();
  } catch (error) {
    if (isError(error)) throw error;
    console.error(`[public-api] ${event.path}`, error);
    throw createError({ statusCode: 502, statusMessage: "Could not load data" });
  }
};
