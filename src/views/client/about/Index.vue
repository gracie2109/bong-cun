<template>
  <div class="container space-y-12 py-10">
    <header class="max-w-2xl space-y-3">
      <span class="text-xs font-semibold uppercase tracking-wide text-primary">
        {{ $t("client.about.eyebrow") }}
      </span>
      <h1 class="text-3xl font-bold md:text-4xl">{{ $t("client.about.title") }}</h1>
      <p class="text-muted-foreground">{{ $t("client.about.intro") }}</p>
    </header>

    <section class="rounded-2xl bg-[#fff8f0] p-6 md:p-10">
      <h2 class="text-xl font-semibold">{{ $t("client.about.mission") }}</h2>
      <p class="mt-2 text-muted-foreground">{{ $t("client.about.missionText") }}</p>
    </section>

    <ul class="grid gap-4 md:grid-cols-3">
      <li v-for="value in values" :key="value" class="rounded-xl border p-5">
        <p class="font-semibold">{{ $t(`client.about.${value}`) }}</p>
        <p class="mt-1 text-sm text-muted-foreground">{{ $t(`client.about.${value}Text`) }}</p>
      </li>
    </ul>

    <Button as-child>
      <RouterLink :to="{ name: 'products' }">{{ $t("client.about.cta") }}</RouterLink>
    </Button>
  </div>
</template>

<script setup lang="ts">
import { Button } from "@/components/ui/button";

const values = ["v1", "v2", "v3"] as const;
</script>
