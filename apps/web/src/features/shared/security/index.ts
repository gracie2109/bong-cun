export { useCanonicalLink } from "./composables/useCanonicalLink";
export { useDomainGuard } from "./composables/useDomainGuard";
export { useSiteConfig } from "./composables/useSiteConfig";
export {
  canonicalUrl,
  hostMatches,
  isAllowedHost,
  parseHostList,
  redirectTarget,
} from "./helpers/hostAllowlist";
export type { SiteConfig } from "./types";
