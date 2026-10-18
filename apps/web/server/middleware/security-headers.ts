import { buildCsp } from "../../config/securityHeaders";

// CSP on every server response (pages and /api). Not in dev: Vite's HMR needs eval and websockets.
export default defineEventHandler((event) => {
  if (import.meta.dev) return;
  const supabaseUrl = (useRuntimeConfig(event).public.supabase as { url?: string } | undefined)?.url;
  setResponseHeader(event, "Content-Security-Policy", buildCsp(supabaseUrl));
});
