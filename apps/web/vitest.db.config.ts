import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

// Tests that run the real database functions. They need a database with every migration applied
// (`supabase db start`, port 54322 by default; set DATABASE_URL for another one) and are kept out
// of `npm test` so the unit tests stay free of any database.
export default defineConfig({
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  test: { environment: "node", include: ["tests/db/**/*.test.ts"], fileParallelism: false, testTimeout: 30_000 },
});
