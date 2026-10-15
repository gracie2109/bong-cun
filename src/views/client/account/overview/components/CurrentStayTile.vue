<template>
  <RouterLink
    :to="stay ? { name: 'account-boarding-detail', params: { id: stay.id } } : { name: 'account-boarding' }"
    class="flex items-center gap-3 rounded-xl border bg-white p-4 transition-colors hover:bg-muted/40"
  >
    <span class="flex size-10 items-center justify-center rounded-full bg-primary/10 text-primary">
      <BedDouble class="size-5" />
    </span>
    <span class="min-w-0">
      <span class="block text-sm font-semibold">{{ $t("client.account.overview.currentStay") }}</span>
      <span v-if="stay" class="block truncate text-xs text-muted-foreground">
        {{ stay.pets.map((pet) => pet.petName).join(", ") }} · {{ stay.code }}
      </span>
      <span v-else class="block text-xs text-muted-foreground">{{ $t("client.account.overview.noStay") }}</span>
    </span>
  </RouterLink>
</template>

<script lang="ts" setup>
import { BedDouble } from "lucide-vue-next";
import type { MyBoardingStay } from "@/types/account";

defineProps<{ stay: MyBoardingStay | null }>();
</script>
