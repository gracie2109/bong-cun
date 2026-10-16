<template>
  <section class="rounded-xl border bg-white">
    <header class="border-b px-4 py-3">
      <h2 class="font-semibold">{{ $t("shop.settings.methods") }}</h2>
      <p class="text-xs text-muted-foreground">{{ $t("shop.settings.methodsHint") }}</p>
    </header>
    <div class="space-y-4 p-4">
      <div class="space-y-1.5">
        <Label>{{ $t("shop.settings.branch") }}</Label>
        <Select v-model="form.onlineBranchId" :disabled="disabled">
          <SelectTrigger><SelectValue :placeholder="$t('shop.settings.branch')" /></SelectTrigger>
          <SelectContent side="bottom">
            <SelectItem v-for="branch in branches" :key="branch.id" :value="branch.id">{{ branch.name }}</SelectItem>
          </SelectContent>
        </Select>
        <p class="text-xs text-muted-foreground">{{ $t("shop.settings.branchHint") }}</p>
        <p v-if="errors.includes('branch')" class="text-xs text-red-600">{{ $t("shop.settings.errors.branch") }}</p>
      </div>

      <label class="flex items-center justify-between gap-3">
        <span>
          <span class="block text-sm font-medium">{{ $t("shop.settings.allowCod") }}</span>
          <span class="block text-xs text-muted-foreground">{{ $t("shop.settings.allowCodHint") }}</span>
        </span>
        <Switch v-model:checked="form.allowCod" :disabled="disabled" />
      </label>

      <label class="flex items-center justify-between gap-3">
        <span>
          <span class="block text-sm font-medium">{{ $t("shop.settings.allowPickup") }}</span>
          <span class="block text-xs text-muted-foreground">{{ $t("shop.settings.allowPickupHint") }}</span>
        </span>
        <Switch v-model:checked="form.allowPickup" :disabled="disabled" />
      </label>

      <div class="space-y-1.5">
        <Label>{{ $t("shop.settings.codMax") }}</Label>
        <Input v-model="form.codMax" inputmode="numeric" :disabled="disabled" />
        <p class="text-xs text-muted-foreground">{{ $t("shop.settings.codMaxHint") }}</p>
        <p v-if="errors.includes('codMax')" class="text-xs text-red-600">{{ $t("shop.settings.errors.codMax") }}</p>
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import type { SettingsForm } from "@bongcun/core/shop";

defineProps<{
  form: SettingsForm;
  branches: { id: string; name: string }[];
  errors: string[];
  disabled: boolean;
}>();
</script>
