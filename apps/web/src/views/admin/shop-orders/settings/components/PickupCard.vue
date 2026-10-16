<template>
  <section class="rounded-xl border bg-white">
    <header class="border-b px-4 py-3">
      <h2 class="font-semibold">{{ $t("shop.settings.pickup") }}</h2>
      <p class="text-xs text-muted-foreground">{{ $t("shop.settings.pickupHint") }}</p>
    </header>
    <div class="space-y-4 p-4">
      <div class="space-y-1.5">
        <Label>{{ $t("shop.settings.pickupAddress") }}</Label>
        <Input v-model="form.pickupAddress" :disabled="disabled" />
      </div>
      <div class="space-y-1.5">
        <Label>{{ $t("shop.settings.pickupNote") }}</Label>
        <Textarea v-model="form.pickupNote" rows="2" :placeholder="$t('shop.settings.pickupNotePlaceholder')" :disabled="disabled" />
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { SettingsForm } from "@bongcun/core/shop";

defineProps<{ form: SettingsForm; disabled: boolean }>();
</script>
