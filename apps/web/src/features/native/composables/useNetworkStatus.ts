import { Network } from "@capacitor/network";

/** Shared online flag for the app. Call it where a Nuxt context exists (plugin body, component setup). */
export const useNetworkStatus = () => {
  const isOnline = useState("native-online", () => true);

  /** Tracks the connection; `onReconnect` runs when it comes back after being lost. */
  const listen = async (onReconnect: () => void) => {
    isOnline.value = (await Network.getStatus()).connected;
    await Network.addListener("networkStatusChange", ({ connected }) => {
      const wasOffline = !isOnline.value;
      isOnline.value = connected;
      if (connected && wasOffline) onReconnect();
    });
  };

  return { isOnline, listen };
};
