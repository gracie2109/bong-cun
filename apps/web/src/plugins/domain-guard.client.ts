import { useDomainGuard } from "@/features/shared/security";

// Runs first in the browser: a copy of the site served from another domain bounces to the real one.
// Skipped in the Capacitor app, whose WebView origin is always localhost.
export default defineNuxtPlugin({
  name: "domain-guard",
  enforce: "pre",
  setup() {
    if (useRuntimeConfig().public.appTarget === "mobile") return;
    useDomainGuard();
  },
});
