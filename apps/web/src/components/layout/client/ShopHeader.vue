<template>
  <HeaderTopBar class="hidden sm:block" />
  <header
    class="sticky top-0 z-40 border-b bg-white/90 backdrop-blur-md transition-shadow duration-300"
    :class="scrolled ? 'border-border shadow-[0_6px_24px_-12px_rgb(41_28_18/0.18)]' : 'border-transparent'"
  >
    <div class="shop-container flex h-16 items-center gap-2 lg:h-[72px] lg:gap-6">
      <MobileNav />
      <ShopLogo />
      <nav class="ml-2 hidden lg:block" :aria-label="$t('client.header.menu')"><NavLinks /></nav>
      <div v-if="route.name !== 'products'" class="ml-auto hidden w-full max-w-[300px] md:block lg:hidden xl:block xl:max-w-[260px]"><HeaderSearch /></div>
      <HeaderActions class="ml-auto" :class="{ 'md:ml-0': route.name !== 'products' }" />
    </div>
  </header>
</template>

<script setup lang="ts">
import { useWindowScroll } from "@vueuse/core";
import { computed } from "vue";
import { useRoute } from "vue-router";
import HeaderActions from "./HeaderActions.vue";
import HeaderSearch from "./HeaderSearch.vue";
import HeaderTopBar from "./HeaderTopBar.vue";
import MobileNav from "./MobileNav.vue";
import NavLinks from "./NavLinks.vue";
import ShopLogo from "./ShopLogo.vue";

const route = useRoute();
const { y } = useWindowScroll();
const scrolled = computed(() => y.value > 8);
</script>
