// The real website's address and the hosts allowed to run the app. Pure, so nuxt.config.ts,
// the domain guard and the tests share one list. Override per deployment with
// NUXT_PUBLIC_SITE_URL and NUXT_PUBLIC_ALLOWED_HOSTS (comma separated, `*` wildcards).

export const DEFAULT_SITE_URL = "https://bong-cun.vercel.app";

/**
 * Production, local dev and Vercel previews of this project. Vercel names previews
 * `bong-cun-<hash>-<team>.vercel.app` / `bong-cun-git-<branch>-<team>.vercel.app`;
 * narrow the pattern to your team with NUXT_PUBLIC_ALLOWED_HOSTS when you know it.
 */
export const DEFAULT_ALLOWED_HOSTS = [
  "bong-cun.vercel.app",
  "bong-cun-*.vercel.app",
  "localhost",
  "127.0.0.1",
].join(",");
