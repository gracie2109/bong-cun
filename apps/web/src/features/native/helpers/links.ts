export type LinkTarget = "internal" | "browser" | "system";

const WEB_PROTOCOLS = ["http:", "https:"];

/**
 * Where a clicked link should open inside the app:
 * internal = the router/WebView, browser = system browser, system = another app (phone, mail, Zalo...).
 */
export const classifyLink = (href: string, appOrigin: string, opensNewTab = false): LinkTarget => {
  if (!href || href.startsWith("#")) return "internal";
  let url: URL;
  try {
    url = new URL(href, appOrigin);
  } catch {
    return "internal";
  }
  if (!WEB_PROTOCOLS.includes(url.protocol)) return "system";
  if (url.origin !== new URL(appOrigin).origin) return "browser";
  return opensNewTab ? "browser" : "internal";
};
