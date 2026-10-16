<template>
  <div class="mx-auto max-w-md rounded-3xl border bg-white p-8 text-center" role="status">
    <span class="mx-auto grid size-16 place-content-center rounded-full bg-sage-soft text-sage">
      <CheckCircle2 class="size-9" />
    </span>
    <h2 class="mt-5 text-2xl font-extrabold tracking-tight">{{ $t("client.booking.doneTitle") }}</h2>
    <p class="mt-2 text-sm text-muted-foreground">{{ $t("client.booking.doneText", { code }) }}</p>
    <p class="mt-5 rounded-2xl border border-dashed border-sage/40 bg-sage-soft/60 py-3 font-mono text-xl font-bold tracking-wider">{{ code }}</p>
    <div class="mt-6 flex flex-wrap justify-center gap-3">
      <Button as-child class="h-11 rounded-full bg-sage px-6 hover:bg-sage/90">
        <RouterLink :to="{ name: 'account-appointments' }">{{ $t("client.booking.viewAppointments") }}</RouterLink>
      </Button>
      <Button as-child variant="outline" class="h-11 rounded-full px-6">
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
