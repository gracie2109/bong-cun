import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

// Unit tests for pure TypeScript only (utils, repositories' rules). No Nuxt, no DOM, no database.
export default defineConfig({
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  test: { environment: "node", include: ["tests/unit/**/*.test.ts"] },
});
