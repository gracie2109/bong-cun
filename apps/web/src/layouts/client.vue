<template>
  <a href="#main" class="sr-only z-50 rounded-full bg-primary px-4 py-2 text-white focus:not-sr-only focus:fixed focus:left-4 focus:top-4">
    {{ $t("client.header.skipToContent") }}
  </a>
  <ShopHeader />
  <main id="main" class="relative min-h-[70vh] w-full">
    <slot />
  </main>
  <ClientFooter />
</template>

<script setup lang="ts">
import ShopHeader from "@/components/layout/client/ShopHeader.vue";
import ClientFooter from "@/features/shop/layout/ClientFooter.vue";

// The shop palette and font; on <html> so sheets and dialogs teleported to <body> share it.
useHead({ htmlAttrs: { class: "shop-theme" } });
</script>
