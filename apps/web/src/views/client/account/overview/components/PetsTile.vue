<template>
  <RouterLink
    :to="{ name: 'account-pets' }"
    class="flex items-center gap-3 rounded-xl border bg-white p-4 transition-colors hover:bg-muted/40"
  >
    <span class="flex size-10 items-center justify-center rounded-full bg-primary/10 text-primary">
      <PawPrint class="size-5" />
    </span>
    <span class="min-w-0">
      <span class="block text-sm font-semibold">{{ $t("client.account.overview.myPets") }}</span>
      <span class="block text-xs text-muted-foreground">
        {{ count === null ? $t("client.account.overview.petsHint") : $t("client.account.overview.petsCount", { n: count }) }}
      </span>
    </span>
  </RouterLink>
</template>

<script lang="ts" setup>
import { PawPrint } from "lucide-vue-next";

/** Null while loading or when the customer has no record yet. */
defineProps<{ count: number | null }>();
</script>
