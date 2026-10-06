import { QueryClient } from "@tanstack/vue-query";

// Factory (not a singleton): Nuxt needs a fresh client per request on the server.
export const createQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: {
        // Replaces Firestore onSnapshot: data is refreshed by invalidation after
        // each mutation and on remount, not by a live subscription.
        staleTime: 30_000,
        refetchOnWindowFocus: false,
        retry: 1,
      },
    },
  });
