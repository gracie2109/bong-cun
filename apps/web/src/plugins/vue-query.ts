import {
  VueQueryPlugin,
  dehydrate,
  hydrate,
  type DehydratedState,
} from "@tanstack/vue-query";
import { createQueryClient } from "@/lib/query-client";

// One QueryClient per request on the server (per app in the browser). Anything
// prefetched during SSR is serialized into the payload and hydrated on the client.
export default defineNuxtPlugin((nuxtApp) => {
  const queryState = useState<DehydratedState | null>("vue-query", () => null);
  const queryClient = createQueryClient();

  nuxtApp.vueApp.use(VueQueryPlugin, { queryClient });

  if (import.meta.server) {
    nuxtApp.hooks.hook("app:rendered", () => {
      queryState.value = dehydrate(queryClient);
    });
  }

  if (import.meta.client) {
    nuxtApp.hooks.hook("app:created", () => {
      if (queryState.value) hydrate(queryClient, queryState.value);
    });
  }
});
