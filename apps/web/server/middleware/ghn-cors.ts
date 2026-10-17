import { appCorsHeaders } from "../utils/appCors";

// Lets the mobile app (a different origin) call the GHN proxy; the GHN token stays on the server.
export default defineEventHandler((event) => {
  if (!event.path.startsWith("/api/ghn/")) return;
  const headers = appCorsHeaders(getRequestHeader(event, "origin"));
  if (!headers) return;
  setResponseHeaders(event, headers);
  if (event.method === "OPTIONS") {
    setResponseStatus(event, 204);
    return "";
  }
});
