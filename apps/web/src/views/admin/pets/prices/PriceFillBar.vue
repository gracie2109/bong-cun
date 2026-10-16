<template>
  <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3 text-sm">
    <span class="font-semibold">{{ $t("petCare.prices.fill") }}</span>
    <Label for="fill-start" class="text-xs text-muted-foreground">{{ $t("petCare.prices.fillStart") }}</Label>
    <Input id="fill-start" v-model="start" type="number" min="0" step="1000" class="w-32" />
    <Label for="fill-step" class="text-xs text-muted-foreground">{{ $t("petCare.prices.fillStep") }}</Label>
    <Input id="fill-step" v-model="step" type="number" min="0" step="1000" class="w-32" />
  </div>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const start = defineModel<string>("start", { required: true });
const step = defineModel<string>("step", { required: true });
</script>
