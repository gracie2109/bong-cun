<template>
  <div v-if="loading" class="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-4">
    <Skeleton v-for="n in 8" :key="n" class="aspect-[3/4] w-full rounded-xl" />
  </div>

  <div v-else-if="failed" class="grid place-items-center gap-3 rounded-xl border bg-white py-16 text-center">
    <p class="text-muted-foreground">{{ $t("client.catalog.error") }}</p>
    <Button variant="outline" @click="emit('retry')">{{ $t("client.catalog.retry") }}</Button>
  </div>

  <div v-else-if="groups.length === 0" class="grid place-items-center gap-3 rounded-xl border bg-white py-16 text-center">
    <img :src="emptyBox" alt="" class="w-28 opacity-80" />
    <p class="text-muted-foreground">{{ $t("client.catalog.empty") }}</p>
  </div>

  <template v-else>
    <div class="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-4">
      <CatalogCard v-for="group in groups" :key="group.id" :group="group" />
    </div>
    <div class="mt-6 space-y-3 rounded-xl border bg-white p-5 text-center">
      <p class="text-sm">{{ $t("client.catalog.showing", { shown: groups.length, total }) }}</p>
      <div class="mx-auto h-1.5 max-w-sm overflow-hidden rounded-full bg-muted">
        <div class="h-full bg-primary" :style="{ width: `${progress}%` }" />
      </div>
      <Button v-if="hasMore" variant="outline" :disabled="loadingMore" @click="emit('loadMore')">
        {{ $t("client.catalog.loadMore") }}
      </Button>
    </div>
  </template>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import emptyBox from "@/assets/empty-box.png";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import type { ShopGroup } from "@/types/catalog";
import CatalogCard from "./CatalogCard.vue";

const props = defineProps<{
  groups: ShopGroup[];
  total: number;
  loading: boolean;
  failed: boolean;
  hasMore: boolean;
  loadingMore: boolean;
}>();
const emit = defineEmits<{ loadMore: []; retry: [] }>();

const progress = computed(() => (props.total > 0 ? Math.min(100, (props.groups.length / props.total) * 100) : 0));
</script>
