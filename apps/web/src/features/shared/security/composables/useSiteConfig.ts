import type { SiteConfig } from "../types";

export const useSiteConfig = (): SiteConfig => {
  const pub = useRuntimeConfig().public;
  return { siteUrl: String(pub.siteUrl), allowedHosts: String(pub.allowedHosts) };
};
