import { App } from "@capacitor/app";
import { decideBackAction } from "../helpers/backButton";

/** Hooks the Android Back button to the router. */
export const useBackButton = () => {
  const router = useRouter();

  const listen = () =>
    App.addListener("backButton", () => {
      const position = (window.history.state as { position?: number } | null)?.position;
      if (decideBackAction(position, router.currentRoute.value.path) === "back") router.back();
      else App.exitApp();
    });

  return { listen };
};
