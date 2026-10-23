<template>
  <Popover v-if="!hidden" class="relative pr-20">
    <PopoverTrigger as-child>
      <button type="button" class="relative cursor-pointer" :aria-label="$t('dashboard.bell.title')">
        <Bell class="size-6" />
        <span
          v-if="total > 0"
          class="absolute -right-2 -top-2 grid min-w-4 place-items-center rounded-full bg-red-600 px-1 text-[10px] font-semibold leading-4 text-white"
        >
          {{ total > 9 ? "9+" : total }}
        </span>
      </button>
    </PopoverTrigger>
    <PopoverContent class="w-80">
      <h2 class="mb-2 text-sm font-bold">{{ $t("dashboard.bell.title") }}</h2>
      <p v-if="!todo.length" class="py-4 text-center text-sm text-muted-foreground">{{ $t("dashboard.actions.empty") }}</p>
      <ul v-else class="divide-y">
        <li v-for="row in todo" :key="row.key">
          <router-link :to="row.to" class="flex items-center justify-between gap-3 py-2 text-sm hover:text-primary">
            <span>{{ $t(`dashboard.actions.${row.key}`) }}</span>
            <span class="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-bold text-amber-800">{{ row.count }}</span>
          </router-link>
        </li>
      </ul>
      <PopoverArrow />
    </PopoverContent>
  </Popover>
</template>

<script lang="ts" setup>
import { Bell } from "lucide-vue-next";
import { Popover, PopoverArrow, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { useBellItems } from "./useBellItems";

const { todo, total, hidden } = useBellItems();
</script>
