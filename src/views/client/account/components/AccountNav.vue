<template>
  <nav class="flex gap-1 overflow-x-auto lg:flex-col lg:overflow-visible" :aria-label="$t('client.account.title')">
    <RouterLink
      v-for="item in ACCOUNT_NAV"
      :key="item.name"
      :to="{ name: item.name }"
      class="flex shrink-0 items-center gap-2 whitespace-nowrap rounded-lg px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:bg-muted"
      active-class="bg-primary/10 text-primary"
      exact-active-class="bg-primary/10 text-primary"
    >
      <component :is="NAV_ICONS[item.icon]" class="size-4" />
      {{ $t(item.label) }}
    </RouterLink>
  </nav>
</template>

<script lang="ts" setup>
import { CalendarClock, LayoutDashboard, MapPin, Package, PawPrint, User } from "lucide-vue-next";
import { ACCOUNT_NAV } from "@/lib/navigations";

const NAV_ICONS: Record<string, unknown> = { CalendarClock, LayoutDashboard, MapPin, Package, PawPrint, User };
</script>
