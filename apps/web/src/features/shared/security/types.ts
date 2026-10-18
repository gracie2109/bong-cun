export type SiteConfig = {
  /** The real website, e.g. `https://bong-cun.vercel.app` (no trailing slash needed). */
  siteUrl: string;
  /** Comma-separated host patterns; `*` matches any run of characters except a dot. */
  allowedHosts: string;
};
