import type { CapacitorConfig } from "@capacitor/cli";

// The web bundle is built by apps/web (npm run generate:mobile) and copied in by `cap sync`.
const config: CapacitorConfig = {
  appId: "vn.bongcun.app",
  appName: "Bông Cún",
  webDir: "../web/.output/public",
  android: { allowMixedContent: false },
  plugins: {
    SplashScreen: { launchShowDuration: 0, backgroundColor: "#F97316" },
  },
};

export default config;
