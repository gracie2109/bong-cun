import { defineConfig } from "vitest/config";

// Contract tests that call the real database functions. They need DATABASE_URL pointing at a database
// with every migration applied (CI: `supabase db start`, then postgresql://postgres:postgres@127.0.0.1:54322/postgres).
// Each test runs in a transaction that is rolled back, so nothing is left behind.
export default defineConfig({
  test: { environment: "node", include: ["tests/db/**/*.test.ts"], testTimeout: 30_000, fileParallelism: false },
});
