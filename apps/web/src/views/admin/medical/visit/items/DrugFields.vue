<template>
  <div class="space-y-3">
    <label v-if="draft.source === 'stock'" class="flex items-center gap-2 text-sm font-medium">
      <input v-model="draft.takeHome" type="checkbox" class="size-4 accent-primary" />
      {{ $t("medical.items.takeHomeHint") }}
    </label>
    <div class="grid gap-3 sm:grid-cols-2">
      <div class="space-y-1.5">
        <Label for="drug-dose">{{ $t("medical.items.dose") }}</Label>
        <Input id="drug-dose" v-model="draft.dose" :placeholder="$t('medical.items.doseHint')" />
      </div>
      <div class="space-y-1.5">
        <Label for="drug-freq">{{ $t("medical.items.frequency") }}</Label>
        <Input id="drug-freq" v-model="draft.frequency" :placeholder="$t('medical.items.frequencyHint')" />
      </div>
      <div class="space-y-1.5">
        <Label for="drug-days">{{ $t("medical.items.days") }}</Label>
        <Input id="drug-days" :model-value="draft.days ?? ''" type="number" min="1" step="1" @update:model-value="draft.days = $event === '' ? null : Number($event)" />
      </div>
      <div class="space-y-1.5">
        <Label for="drug-route">{{ $t("medical.items.route") }}</Label>
        <Input id="drug-route" v-model="draft.route" :placeholder="$t('medical.items.routeHint')" />
      </div>
    </div>
    <div class="space-y-1.5">
      <Label for="drug-note">{{ $t("medical.items.instructions") }}</Label>
      <Input id="drug-note" v-model="draft.instructions" />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { DrugDraft } from "./itemDraft";

const draft = defineModel<DrugDraft>("draft", { required: true });
</script>
