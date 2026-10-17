import { useQueryClient } from "@tanstack/vue-query";
import { Keyboard, KeyboardResize } from "@capacitor/keyboard";
import { SplashScreen } from "@capacitor/splash-screen";
import { StatusBar, Style } from "@capacitor/status-bar";
import { useBackButton } from "./useBackButton";
import { useExternalLinks } from "./useExternalLinks";
import { useNetworkStatus } from "./useNetworkStatus";

const SHOP_ORANGE = "#F97316";

/** Wiring of the native pieces when the app starts. Call it from the plugin body; run `start` once mounted. */
export const useNativeSetup = () => {
  const nuxtApp = useNuxtApp();
  const backButton = useBackButton();
  const externalLinks = useExternalLinks();
  const network = useNetworkStatus();

  const start = async () => {
    await StatusBar.setStyle({ style: Style.Dark });
    await StatusBar.setBackgroundColor({ color: SHOP_ORANGE });
    // Resize the page (not the viewport overlay) so inputs in checkout are not covered by the keyboard.
    await Keyboard.setResizeMode({ mode: KeyboardResize.Body });
    backButton.listen();
    externalLinks.listen();
    await network.listen(() => nuxtApp.vueApp.runWithContext(() => useQueryClient()).refetchQueries());
    await SplashScreen.hide();
  };

  return { start };
};
