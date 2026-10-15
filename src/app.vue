<template>
  <div class="app_xcontent">
    <NuxtLayout v-if="isOnline">
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

const route = useRoute();
// A page re-mounts on any URL change, except pages that keep their filters in the query and
// update in place (the product list), so typing in its search box keeps focus.
const pageKey = (to: RouteLocationNormalizedLoaded) => (to.meta.keepOnQuery ? to.path : to.fullPath);
const { t, localeProperties } = useI18n();
// SSR-safe: reports online on the server and tracks the browser state after hydration.
const isOnline = useOnline();

const title = computed(() => t(`pageMeta.${route.meta.titleKey}`));
const description = computed(() => t("seo.description"));

useHead({
  title,
  // Follows the active locale (the cookie-selected one during SSR).
  htmlAttrs: { lang: () => localeProperties.value.language },
});
useSeoMeta({
  description,
  ogTitle: title,
  ogDescription: description,
  ogType: "website",
  robots: () => (route.meta.noindex ? "noindex, follow" : undefined),
});
</script>
