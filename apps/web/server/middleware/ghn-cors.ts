import { appCorsHeaders } from "../utils/appCors";

// Lets the mobile app (a different origin) call the GHN proxy and the public catalog routes;
// the GHN token and the database stay on the server.
const APP_API_PREFIXES = ["/api/ghn/", "/api/public/"];

export default defineEventHandler((event) => {
  if (!APP_API_PREFIXES.some((prefix) => event.path.startsWith(prefix))) return;
  // The routes are cached (CDN, server), and the answer differs per Origin.
  appendResponseHeader(event, "Vary", "Origin");
  const headers = appCorsHeaders(getRequestHeader(event, "origin"));
  if (!headers) return;
  setResponseHeaders(event, headers);
  if (event.method === "OPTIONS") {
    setResponseStatus(event, 204);
    return "";
  }
});
