/**
 * Whether cached query data must be dropped when the signed-in account changes.
 * `undefined` = no session applied yet (first load: nothing cached by another account).
 * Token refreshes keep the same user id, so they never clear the cache.
 */
export const shouldClearQueryCache = (
  previousUserId: string | null | undefined,
  nextUserId: string | null,
) => previousUserId !== undefined && previousUserId !== nextUserId;
