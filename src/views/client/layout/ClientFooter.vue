<template>
  <footer class="mt-16 bg-foreground text-sm text-white/70 md:mt-24">
    <FooterCta />
    <div class="shop-container grid gap-10 py-12 md:grid-cols-2 lg:grid-cols-[1.4fr_1fr_1fr_1.2fr] lg:gap-8">
      <div class="space-y-4">
        <ShopLogo inverted />
        <p class="max-w-xs leading-relaxed">{{ $t("client.footer.tagline") }}</p>
      </div>

      <FooterLinks :title="$t('client.footer.shop')" :links="shopLinks" />
      <FooterLinks :title="$t('client.footer.links')" :links="pageLinks" />

      <div class="space-y-4">
        <h3 class="text-sm font-semibold text-white">{{ $t("client.footer.contact") }}</h3>
        <StoreContactList />
      </div>
    </div>
    <div class="border-t border-white/10">
      <div class="shop-container py-5">
        <p class="text-xs text-white/50">© {{ year }} {{ STORE_INFO.name }}. {{ $t("client.footer.rights") }}</p>
      </div>
    </div>
  </footer>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import ShopLogo from "@/components/layout/client/ShopLogo.vue";
import { STORE_INFO } from "@/config/storeInfo";
import FooterCta from "./FooterCta.vue";
import FooterLinks from "./FooterLinks.vue";
import StoreContactList from "./StoreContactList.vue";

const { t } = useI18n();
const year = new Date().getFullYear();

const shopLinks = computed(() => [
  { label: t("client.nav.products"), to: { name: "products" } },
  { label: t("client.nav.spa"), to: { name: "spa" } },
  { label: t("client.footer.bookSpa"), to: { path: "/spa/book" } },
  { label: t("shop.cart.title"), to: { name: "cart" } },
]);
const pageLinks = computed(() => [
  { label: t("client.nav.about"), to: { name: "about-us" } },
  { label: t("client.nav.contact"), to: { name: "contact" } },
  { label: t("client.menu.account"), to: { name: "account" } },
  { label: t("client.menu.orders"), to: { name: "account-orders" } },
]);
</script>
