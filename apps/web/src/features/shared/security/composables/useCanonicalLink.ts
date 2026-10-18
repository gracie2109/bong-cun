import { computed } from "vue";
import { useRoute } from "vue-router";
import { canonicalUrl } from "../helpers/hostAllowlist";
import { useSiteConfig } from "./useSiteConfig";

/** `<link rel="canonical">` and `og:url` for the current page, always on the real domain. */
export const useCanonicalLink = () => {
  const route = useRoute();
  const { siteUrl } = useSiteConfig();
  const href = computed(() => canonicalUrl(siteUrl, route.path));

  useHead({ link: [{ rel: "canonical", href }] });
  useSeoMeta({ ogUrl: href });
};
