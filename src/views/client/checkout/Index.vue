<template>
  <div class="container grid min-h-[50vh] place-content-center gap-4 py-16 text-center md:px-12 lg:px-20">
    <h1 class="text-2xl font-bold">{{ $t("shop.checkout.title") }}</h1>
    <p class="text-muted-foreground">{{ $t("shop.checkout.soon") }}</p>
    <div>
      <Button as-child variant="outline">
        <router-link :to="{ name: 'cart' }">{{ $t("shop.checkout.backToCart") }}</router-link>
      </Button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
</script>
