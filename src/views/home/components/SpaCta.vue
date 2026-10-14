<template>
  <section class="container py-12">
    <div class="grid items-center gap-8 rounded-2xl bg-[#fff8f0] p-6 md:grid-cols-2 md:p-10">
      <div class="space-y-4">
        <span class="text-xs font-semibold uppercase tracking-wide text-primary">
          {{ $t("client.home.spaCta.badge") }}
        </span>
        <h2 class="text-3xl font-bold">{{ $t("client.home.spaCta.title") }}</h2>
        <p class="text-muted-foreground">{{ $t("client.home.spaCta.text") }}</p>
        <Button size="lg" as-child>
          <RouterLink :to="{ name: 'contact' }">{{ $t("client.home.spaCta.button") }}</RouterLink>
        </Button>
      </div>
      <ul class="grid gap-3 sm:grid-cols-3 md:grid-cols-1 lg:grid-cols-3">
        <li v-for="tip in tips" :key="tip" class="rounded-xl bg-white p-4 shadow-sm">
          <p class="font-semibold">{{ $t(`client.home.spaCta.${tip}`) }}</p>
          <p class="mt-1 text-sm text-muted-foreground">{{ $t(`client.home.spaCta.${tip}Text`) }}</p>
        </li>
      </ul>
    </div>
  </section>
</template>

<script setup lang="ts">
import { Button } from "@/components/ui/button";

const tips = ["tip1", "tip2", "tip3"] as const;
</script>
