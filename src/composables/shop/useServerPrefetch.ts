import { onServerPrefetch } from "vue";

type Suspensible = { suspense: () => Promise<unknown> };

/**
 * During SSR, wait for these queries before the page is rendered. Without it the server renders the
 * loading state while the query finishes in the background and lands in the hydrated cache, so the
 * client renders the data and Vue reports a hydration mismatch. A failed query renders its own error state.
 * Pass a function for queries that depend on an earlier one (they run in order).
 */
export const useServerPrefetch = (...steps: (Suspensible | (() => Suspensible[]))[]) =>
  onServerPrefetch(async () => {
    for (const step of steps) {
      const queries = typeof step === "function" ? step() : [step];
      await Promise.allSettled(queries.map((query) => query.suspense()));
    }
  });
