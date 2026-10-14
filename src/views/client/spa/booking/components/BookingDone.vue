<template>
  <div class="mx-auto max-w-md space-y-4 rounded-xl border bg-white p-8 text-center">
    <span class="mx-auto flex size-14 items-center justify-center rounded-full bg-green-100 text-green-600">
      <CheckCircle2 class="size-8" />
    </span>
    <h2 class="text-xl font-bold">{{ $t("client.booking.doneTitle") }}</h2>
    <p class="text-sm text-muted-foreground">{{ $t("client.booking.doneText", { code }) }}</p>
    <p class="rounded-lg bg-muted/50 py-2 font-mono text-lg font-semibold">{{ code }}</p>
    <div class="flex flex-wrap justify-center gap-2">
      <Button as-child>
        <RouterLink :to="{ name: 'account-appointments' }">{{ $t("client.booking.viewAppointments") }}</RouterLink>
      </Button>
      <Button as-child variant="outline">
        <RouterLink :to="{ name: 'spa' }">{{ $t("client.booking.backToSpa") }}</RouterLink>
      </Button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { CheckCircle2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";

defineProps<{ code: string }>();
</script>
