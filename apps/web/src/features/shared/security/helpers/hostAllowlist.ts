// Pure helpers for the "wrong domain" guard and canonical links.

/** `"a.com, *.b.com"` → `["a.com", "*.b.com"]`, lower-cased, blanks dropped. */
export const parseHostList = (value: string): string[] =>
  value
    .split(",")
    .map((h) => h.trim().toLowerCase())
    .filter(Boolean);

const escapeRegex = (text: string): string => text.replace(/[.+?^${}()|[\]\\]/g, "\\$&");

/** `*` stands for one or more characters inside a single label, so `bong-cun-*.vercel.app` never matches `evil.com/.vercel.app` tricks. */
export const hostMatches = (host: string, pattern: string): boolean => {
  const source = pattern.split("*").map(escapeRegex).join("[^.]+");
  return new RegExp(`^${source}$`).test(host.toLowerCase());
};

export const isAllowedHost = (host: string, patterns: string[]): boolean =>
  patterns.some((pattern) => hostMatches(host, pattern));

/** Same path, query and hash on the real site. */
export const redirectTarget = (siteUrl: string, location: { pathname: string; search: string; hash: string }): string =>
  `${siteUrl.replace(/\/+$/, "")}${location.pathname}${location.search}${location.hash}`;

/** Canonical URL of a page: the real site plus the path, without query or hash. */
export const canonicalUrl = (siteUrl: string, path: string): string => {
  const base = siteUrl.replace(/\/+$/, "");
  const clean = path.split(/[?#]/)[0] || "/";
  return clean === "/" ? `${base}/` : `${base}${clean.replace(/\/+$/, "")}`;
};
