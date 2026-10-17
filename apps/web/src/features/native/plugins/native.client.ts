import { Capacitor } from "@capacitor/core";
import { useAppTarget } from "../composables/useAppTarget";
import { useNativeSetup } from "../composables/useNativeSetup";

// Registered by the mobile build only (config/mobileTarget.ts); the website never loads this file.
// Opening the mobile build in a desktop browser skips the plugin calls (they only exist on a device).
export default defineNuxtPlugin((nuxtApp) => {
  if (!useAppTarget().isNativeApp || !Capacitor.isNativePlatform()) return;
  const native = useNativeSetup();
  nuxtApp.hook("app:mounted", () => {
    native.start().catch((error) => console.error("native setup failed", error));
  });
});
