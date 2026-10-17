import { defineAsyncComponent } from "vue";

export { useAppTarget } from "./composables/useAppTarget";
export type { AppTarget } from "./types";

// Lazy, so the website build never loads the Capacitor plugins the banner depends on.
export const OfflineBanner = defineAsyncComponent(() => import("./components/OfflineBanner.vue"));
