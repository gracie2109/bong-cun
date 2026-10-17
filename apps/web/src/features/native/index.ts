import { defineAsyncComponent } from "vue";

export { useAppTarget } from "./composables/useAppTarget";
export type { AppTarget } from "./types";

// Lazy, so the website build never loads the Capacitor plugins or app-only screens.
export const OfflineBanner = defineAsyncComponent(() => import("./components/OfflineBanner.vue"));
export const AppTabBar = defineAsyncComponent(() => import("./components/AppTabBar.vue"));
export const StaffWebNotice = defineAsyncComponent(() => import("./components/StaffWebNotice.vue"));
