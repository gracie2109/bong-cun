<template>
  <!-- Spacer keeps the last content clear of the fixed bar. -->
  <div class="h-[calc(3.5rem+env(safe-area-inset-bottom))]" aria-hidden="true" />
  <nav
    class="fixed inset-x-0 bottom-0 z-40 flex border-t bg-white pb-[env(safe-area-inset-bottom)]"
    :aria-label="$t('client.header.menu')"
  >
    <AppTabBarItem
      v-for="tab in tabs"
      :key="tab.id"
      :label="$t(tab.labelKey)"
      :icon="ICONS[tab.id]"
      :active="activeTab === tab.id"
      :badge="badgeFor(tab)"
      @open="open(tab)"
    />
  </nav>
</template>

<script setup lang="ts">
import type { Component } from "vue";
import { Home, Scissors, ShoppingBag, ShoppingBasket, UserRound } from "lucide-vue-next";
import { useAppTabs } from "../composables/useAppTabs";
import type { TabId } from "../helpers/tabs";
import AppTabBarItem from "./AppTabBarItem.vue";

const ICONS: Record<TabId, Component> = {
  home: Home,
  products: ShoppingBasket,
  spa: Scissors,
  cart: ShoppingBag,
  account: UserRound,
};

const { tabs, activeTab, badgeFor, open } = useAppTabs();
</script>
