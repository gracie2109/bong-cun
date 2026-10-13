<template>
  <div class="mx-auto flex max-w-sm flex-col items-center gap-4 py-16 text-center">
    <img :src="emptyBox" alt="" class="w-40" />
    <p class="text-lg font-semibold">{{ $t("shop.cart.empty") }}</p>
    <p class="text-sm text-muted-foreground">{{ $t("shop.cart.emptyHint") }}</p>
    <Button as-child>
      <router-link :to="{ name: 'home' }">{{ $t("shop.cart.continue") }}</router-link>
    </Button>
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import emptyBox from "@/assets/empty-box.png";
</script>
