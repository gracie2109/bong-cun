<template>
  <section v-if="state !== 'hidden'" class="flex h-full min-h-0 flex-col rounded-xl border bg-white p-4" :aria-busy="state === 'loading'">
    <header class="mb-3 flex flex-wrap items-center justify-between gap-2">
      <h3 class="flex items-center gap-2 text-sm font-semibold">
        <component :is="icon" v-if="icon" class="size-4 text-primary" />
        {{ title }}
      </h3>
      <router-link v-if="to && (state === 'ready' || state === 'empty')" :to="to" class="text-xs text-primary hover:underline">
        {{ linkLabel || $t("dashboard.open") }}
      </router-link>
    </header>

    <div v-if="state === 'loading'" class="space-y-2" data-test="widget-loading">
      <Skeleton class="h-6 w-1/2" />
      <Skeleton class="h-6 w-3/4" />
    </div>
    <p v-else-if="state === 'needsBranch'" class="text-sm text-muted-foreground">{{ $t("dashboard.state.needsBranch") }}</p>
    <p v-else-if="state === 'forbidden'" class="text-sm text-muted-foreground">{{ $t("dashboard.state.forbidden") }}</p>
    <div v-else-if="state === 'error'" class="flex flex-wrap items-center gap-3 text-sm">
      <span class="text-red-600">{{ $t("dashboard.state.error") }}</span>
      <button type="button" class="font-semibold text-primary hover:underline" @click="emit('retry')">{{ $t("dashboard.state.retry") }}</button>
    </div>
    <p v-else-if="state === 'empty'" class="text-sm text-muted-foreground">{{ emptyText || $t("dashboard.state.empty") }}</p>
    <div v-else class="min-h-0 flex-1 overflow-auto"><slot /></div>
  </section>
</template>

<script lang="ts" setup>
import type { Component } from "vue";
import type { RouteLocationRaw } from "vue-router";
import { Skeleton } from "@/components/ui/skeleton";
import type { WidgetState } from "./types";

defineProps<{
  title: string;
  state: WidgetState;
  icon?: Component;
  to?: RouteLocationRaw;
  linkLabel?: string;
  emptyText?: string;
}>();
const emit = defineEmits<{ retry: [] }>();
</script>
