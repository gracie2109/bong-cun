<template>
  <section v-if="groups.length > 0" class="space-y-4 border-t pt-8">
    <div class="flex items-end justify-between gap-4">
      <h2 class="text-xl font-semibold">{{ $t("client.product.related") }}</h2>
      <RouterLink :to="{ name: 'products' }" class="text-sm font-semibold text-primary">
        {{ $t("client.home.viewAll") }}
      </RouterLink>
    </div>
    <div class="grid grid-cols-2 gap-4 md:grid-cols-4">
      <CatalogCard v-for="group in groups" :key="group.id" :group="group" />
    </div>
  </section>
</template>

<script lang="ts" setup>
import type { ShopGroup } from "@/types/catalog";
import CatalogCard from "@/views/client/catalog/components/CatalogCard.vue";

defineProps<{ groups: ShopGroup[] }>();
</script>
