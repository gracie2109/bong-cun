import { isAllowedHost, parseHostList, redirectTarget } from "../helpers/hostAllowlist";
import { useSiteConfig } from "./useSiteConfig";

/**
 * Browser only. When the page runs on a host that is not ours (a mirror or a proxy of the
 * site), sends the visitor to the same page on the real domain. Returns true when it redirected.
 */
export const useDomainGuard = (): boolean => {
  const { siteUrl, allowedHosts } = useSiteConfig();
  const { hostname, pathname, search, hash } = window.location;
  if (isAllowedHost(hostname, parseHostList(allowedHosts))) return false;
  window.location.replace(redirectTarget(siteUrl, { pathname, search, hash }));
  return true;
};
