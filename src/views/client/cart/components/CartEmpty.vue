<template>
  <EmptyState :title="$t('shop.cart.empty')" :text="$t('shop.cart.emptyHint')">
    <template #icon><ShoppingBag class="size-10" /></template>
    <Button as-child class="h-11 rounded-full px-6">
      <RouterLink :to="{ name: 'products' }">{{ $t("shop.cart.continue") }}</RouterLink>
    </Button>
    <Button as-child variant="outline" class="h-11 rounded-full px-6">
      <RouterLink :to="{ name: 'spa' }">{{ $t("client.catalog.seeSpa") }}</RouterLink>
    </Button>
  </EmptyState>
</template>

<script lang="ts" setup>
import { ShoppingBag } from "lucide-vue-next";
import EmptyState from "@/components/shop/EmptyState.vue";
import { Button } from "@/components/ui/button";
</script>
