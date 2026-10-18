<template>
  <div class="app_xcontent">
    <OfflineBanner v-if="isNativeApp" />
    <NuxtLayout v-if="isOnline || isNativeApp">
      <NuxtPage :page-key="pageKey" />
    </NuxtLayout>
    <div v-else><ServerOffline /></div>
  </div>
  <div class="absolute right-0 top-36 z-[9999] border">
    <ClientOnly>
      <Toaster position="top-center" rich-colors />
    </ClientOnly>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useRoute, type RouteLocationNormalizedLoaded } from "vue-router";
import { useI18n } from "vue-i18n";
import { useOnline } from "@vueuse/core";
import { Toaster } from "@/components/ui/sonner";
import ServerOffline from "./components/ServerOffline.vue";
import { OfflineBanner, useAppTarget } from "@/features/native";
import { useCanonicalLink, useSiteConfig } from "@/features/shared/security";
import { STORE_INFO } from "@/config/storeInfo";

const route = useRoute();
// A page re-mounts on any URL change, except pages that keep their filters in the query and
// update in place (the product list), so typing in its search box keeps focus.
const pageKey = (to: RouteLocationNormalizedLoaded) => (to.meta.keepOnQuery ? to.path : to.fullPath);
const { t, localeProperties } = useI18n();
// SSR-safe: reports online on the server and tracks the browser state after hydration.
const isOnline = useOnline();
// In the app the pages stay visible when the connection drops; a banner says so instead.
const { isNativeApp } = useAppTarget();

const title = computed(() => t(`pageMeta.${route.meta.titleKey}`));
const description = computed(() => t("seo.description"));

const { siteUrl } = useSiteConfig();
const ogImage = `${siteUrl.replace(/\/+$/, "")}/og-image.png`;

useHead({
  title,
  titleTemplate: (page?: string) => (page ? `${page} | ${STORE_INFO.brand}` : STORE_INFO.brand),
  // Follows the active locale (the cookie-selected one during SSR).
  htmlAttrs: { lang: () => localeProperties.value.language },
});
useSeoMeta({
  description,
  ogTitle: () => `${title.value} | ${STORE_INFO.brand}`,
  ogDescription: description,
  ogType: "website",
  ogSiteName: STORE_INFO.brand,
  ogImage,
  ogImageWidth: 1200,
  ogImageHeight: 630,
  twitterCard: "summary_large_image",
  robots: () => (route.meta.noindex ? "noindex, follow" : undefined),
});
// Copies of the site still point search engines at the real domain.
useCanonicalLink();
</script>
