import type { AppTarget } from "../types";

/** Which build is running. `isNativeApp` is true only in the Capacitor app build. */
export const useAppTarget = () => {
  const target = useRuntimeConfig().public.appTarget as AppTarget;
  return { target, isNativeApp: target === "mobile" };
};
