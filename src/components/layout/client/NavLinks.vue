<template>
  <ul class="flex items-center xl:gap-1">
    <li v-for="item in SHOP_NAV" :key="item.name">
      <RouterLink
        :to="{ name: item.name }"
        class="nav-link relative inline-flex h-10 items-center whitespace-nowrap rounded-full px-3 text-[15px] font-medium transition-colors hover:text-primary"
        :class="isNavActive(route.name, item.name) ? 'is-active text-primary' : 'text-foreground/80'"
        :aria-current="isNavActive(route.name, item.name) ? 'page' : undefined"
      >
        {{ $t(item.title) }}
      </RouterLink>
    </li>
  </ul>
</template>

<script setup lang="ts">
import { useRoute } from "vue-router";
import { SHOP_NAV } from "@/config/shopNav";
import { isNavActive } from "@/utils/shop/nav";

const route = useRoute();
</script>

<style scoped>
.nav-link::after {
  content: "";
  position: absolute;
  left: 0.75rem;
  right: 0.75rem;
  bottom: 0.25rem;
  height: 2px;
  border-radius: 2px;
  background: hsl(var(--primary));
  transform: scaleX(0);
  transform-origin: left;
  transition: transform 260ms var(--ease-out);
}
.nav-link:hover::after,
.nav-link.is-active::after {
  transform: scaleX(1);
}
</style>
