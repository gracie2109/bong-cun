<template>
  <div class="space-y-4">
    <div class="grid grid-cols-3 gap-3">
      <div class="col-span-2 space-y-1">
        <Label for="vaccine-name">{{ $t("medical.vaccines.name") }}</Label>
        <Input id="vaccine-name" v-model="draft.name" :placeholder="$t('medical.vaccines.namePlaceholder')" />
      </div>
      <div class="space-y-1">
        <Label>{{ $t("medical.vaccines.kind") }}</Label>
        <Select v-model="draft.kind">
          <SelectTrigger :aria-label="$t('medical.vaccines.kind')"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="kind in VACCINE_KINDS" :key="kind" :value="kind">{{ $t(`medical.vaccines.kinds.${kind}`) }}</SelectItem>
          </SelectContent>
        </Select>
      </div>
    </div>

    <div class="space-y-2">
      <p class="text-sm font-medium">{{ $t("medical.vaccines.species") }}</p>
      <p class="text-xs text-muted-foreground">{{ $t("medical.common.speciesHint") }}</p>
      <ChipPicker v-model="draft.speciesIds" :options="species" />
    </div>

    <div class="space-y-1">
      <Label>{{ $t("medical.vaccines.product") }}</Label>
      <div v-if="draft.product" class="flex items-center justify-between gap-2 rounded-lg border bg-muted/40 px-3 py-2 text-sm">
        <span class="min-w-0 truncate font-medium">{{ draft.product.name }}</span>
        <Button type="button" size="sm" variant="ghost" @click="draft.product = null">{{ $t("medical.vaccines.clearProduct") }}</Button>
      </div>
      <ProductPicker v-else @pick="(product) => (draft.product = { id: product.id, name: product.name, unit: product.unit })" />
      <p class="text-xs text-muted-foreground">{{ $t("medical.vaccines.productHint") }}</p>
    </div>

    <fieldset class="space-y-3 rounded-lg border p-3">
      <legend class="px-1 text-sm font-medium">{{ $t("medical.vaccines.protocol") }}</legend>
      <p class="text-xs text-muted-foreground">{{ $t("medical.vaccines.protocolHint") }}</p>
      <div class="grid grid-cols-2 gap-3">
        <div class="space-y-1">
          <Label for="vaccine-doses">{{ $t("medical.vaccines.seriesDoses") }}</Label>
          <Input id="vaccine-doses" v-model="draft.seriesDoses" type="number" min="1" max="10" step="1" />
        </div>
        <div class="space-y-1">
          <Label for="vaccine-gap">{{ $t("medical.vaccines.seriesGap") }}</Label>
          <Input id="vaccine-gap" v-model="draft.seriesIntervalDays" type="number" min="1" step="1" :disabled="draft.seriesDoses === '1'" />
        </div>
        <div class="space-y-1">
          <Label for="vaccine-booster">{{ $t("medical.vaccines.booster") }}</Label>
          <Input id="vaccine-booster" v-model="draft.boosterIntervalDays" type="number" min="1" step="1" :placeholder="$t('medical.vaccines.noReminder')" />
        </div>
        <div class="space-y-1">
          <Label for="vaccine-age">{{ $t("medical.vaccines.minAge") }}</Label>
          <Input id="vaccine-age" v-model="draft.minAgeWeeks" type="number" min="0" step="1" :placeholder="$t('medical.vaccines.noLimit')" />
        </div>
      </div>
    </fieldset>

    <div class="grid grid-cols-2 items-end gap-3">
      <div class="space-y-1">
        <Label for="vaccine-sort">{{ $t("medical.common.sortOrder") }}</Label>
        <Input id="vaccine-sort" v-model="draft.sortOrder" type="number" step="1" />
      </div>
      <label class="flex items-center gap-2 pb-2 text-sm">
        <Switch v-model="draft.isActive" :aria-label="$t('medical.common.active')" />
        {{ $t("medical.common.active") }}
      </label>
    </div>
  </div>
</template>

<script lang="ts" setup>
import ChipPicker from "@/components/common/ChipPicker.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { VACCINE_KINDS } from "@bongcun/core/medical";
import { ProductPicker } from "@/features/admin/inventory";
import type { VaccineTypeDraft } from "./vaccineTypeDraft";

defineProps<{ species: { id: string; name: string }[] }>();
const draft = defineModel<VaccineTypeDraft>("draft", { required: true });
</script>
