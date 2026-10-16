<template>
  <div class="space-y-2">
    <p class="text-sm font-medium">{{ $t("boarding.types.branchPrices") }}</p>
    <p class="text-xs text-muted-foreground">{{ $t("boarding.types.branchPricesHint") }}</p>
    <div v-for="branch in branches" :key="branch.id" class="rounded-lg border p-3">
      <div class="flex items-center justify-between gap-3">
        <span class="text-sm font-medium">{{ branch.code }} · {{ branch.name }}</span>
        <Switch
          :model-value="prices[branch.id]?.enabled === true"
          :aria-label="$t('boarding.types.ownPrice')"
          @update:model-value="(value: boolean) => toggle(branch.id, value)"
        />
      </div>
      <div v-if="prices[branch.id]?.enabled" class="mt-3 grid grid-cols-2 gap-3">
        <div class="space-y-1">
          <Label :for="`branch-night-${branch.id}`">{{ $t("boarding.types.nightPrice") }}</Label>
          <Input :id="`branch-night-${branch.id}`" v-model="prices[branch.id].nightPrice" type="number" min="0" step="1000" />
        </div>
        <div class="space-y-1">
          <Label :for="`branch-extra-${branch.id}`">{{ $t("boarding.types.extraPetPrice") }}</Label>
          <Input :id="`branch-extra-${branch.id}`" v-model="prices[branch.id].extraPetNightPrice" type="number" min="0" step="1000" />
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import type { Branch } from "@bongcun/supabase/users";
import type { BranchPriceDraft } from "./kennelTypeDraft";

defineProps<{ branches: Branch[] }>();

const prices = defineModel<Record<string, BranchPriceDraft>>("prices", { required: true });

// Switching a branch on starts it from empty boxes; switching it off keeps what was typed until saved.
const toggle = (branchId: string, enabled: boolean) => {
  const current = prices.value[branchId] ?? { nightPrice: "", extraPetNightPrice: "" };
  prices.value[branchId] = { ...current, enabled };
};
</script>
