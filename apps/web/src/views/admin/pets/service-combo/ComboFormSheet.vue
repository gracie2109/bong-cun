<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ combo ? $t("petCare.combos.edit") : $t("petCare.combos.add") }}</SheetTitle>
        <SheetDescription class="sr-only">{{ $t("petCare.combos.subtitle") }}</SheetDescription>
      </SheetHeader>

      <form id="combo-form" class="flex-1 space-y-5 overflow-y-auto px-6 py-5" @submit.prevent="submit">
        <div class="space-y-2">
          <Label for="combo-name">{{ $t("petCare.combos.form.name") }}</Label>
          <Input id="combo-name" v-model="name" />
          <p v-if="submitted && !name.trim()" class="text-sm text-red-600">{{ $t("petCare.common.required") }}</p>
        </div>

        <div class="space-y-2">
          <Label for="combo-desc">{{ $t("petCare.combos.form.desc") }}</Label>
          <Textarea id="combo-desc" v-model="desc" class="resize-none" rows="2" />
        </div>

        <div class="space-y-2">
          <Label>{{ $t("petCare.combos.form.species") }}</Label>
          <ChipPicker v-model="speciesIds" :options="speciesOptions" />
          <p v-if="submitted && speciesIds.length === 0" class="text-sm text-red-600">
            {{ $t("petCare.combos.form.errSpecies") }}
          </p>
        </div>

        <div class="space-y-2">
          <Label>{{ $t("petCare.combos.form.services") }}</Label>
          <p v-if="speciesIds.length === 0" class="text-sm text-muted-foreground">
            {{ $t("petCare.combos.form.pickSpeciesFirst") }}
          </p>
          <template v-else>
            <p class="text-xs text-muted-foreground">{{ $t("petCare.combos.form.servicesHint") }}</p>
            <ChipPicker v-model="serviceIds" :options="serviceOptions" />
          </template>
          <p v-if="submitted && serviceIds.length === 0" class="text-sm text-red-600">
            {{ $t("petCare.combos.form.errServices") }}
          </p>
        </div>

        <div class="grid gap-4 sm:grid-cols-2">
          <div class="space-y-2">
            <Label for="combo-origin">{{ $t("petCare.combos.form.originPrice") }}</Label>
            <Input id="combo-origin" :model-value="originPrice" disabled />
          </div>
          <div class="space-y-2">
            <Label for="combo-price">{{ $t("petCare.combos.form.price") }}</Label>
            <Input id="combo-price" v-model="price" type="number" min="0" step="1000" inputmode="numeric" />
            <p v-if="submitted && !priceValid" class="text-sm text-red-600">{{ $t("petCare.services.form.errPrice") }}</p>
            <p v-if="savings > 0" class="text-xs font-medium text-green-700">
              {{ $t("petCare.combos.form.savings", { amount: formatPrice(savings) }) }}
            </p>
          </div>
          <div class="space-y-2">
            <Label for="combo-duration">{{ $t("petCare.combos.form.duration") }}</Label>
            <Input id="combo-duration" v-model="duration" type="number" min="0" max="1439" step="5" inputmode="numeric" />
            <p v-if="totalDuration > 0" class="text-xs text-muted-foreground">
              {{ $t("petCare.combos.form.totalDuration", { n: totalDuration }) }}
            </p>
          </div>
          <div class="space-y-2">
            <Label>{{ $t("petCare.combos.form.mark") }}</Label>
            <Select v-model="markAsId">
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="mark in COMBO_MARKS" :key="mark" :value="mark">
                  {{ $t(`petCare.combos.marks.${mark}`) }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>

        <div class="space-y-2">
          <Label>{{ $t("petCare.combos.form.promoTime") }}</Label>
          <div class="grid gap-4 sm:grid-cols-2">
            <div class="space-y-1">
              <Label for="combo-from" class="text-xs text-muted-foreground">{{ $t("petCare.combos.form.from") }}</Label>
              <Input id="combo-from" v-model="promoFrom" type="date" />
            </div>
            <div class="space-y-1">
              <Label for="combo-to" class="text-xs text-muted-foreground">{{ $t("petCare.combos.form.to") }}</Label>
              <Input id="combo-to" v-model="promoTo" type="date" :min="promoFrom" />
            </div>
          </div>
        </div>

        <label class="flex items-center gap-3 text-sm">
          <Switch v-model="sellable" />
          {{ $t("petCare.combos.form.sellable") }}
        </label>
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button type="button" variant="outline" @click="emit('update:open', false)">
          {{ $t("petCare.common.cancel") }}
        </Button>
        <Button type="submit" form="combo-form" :disabled="pending">{{ $t("petCare.common.save") }}</Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import ChipPicker from "@/components/common/ChipPicker.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import { formatPrice } from "@/lib/utils";
import { useCreatePetCombo, useUpdatePetCombo } from "@/queries/petCombos";
import { useSpeciesOptions } from "@/queries/species";
import type { PetCombo } from "@/repositories/petCombos";
import { COMBO_MARKS } from "./comboStatus";
import { useComboForm } from "./useComboForm";

const props = defineProps<{ open: boolean; combo: PetCombo | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const speciesQuery = useSpeciesOptions();
const speciesOptions = computed(() => speciesQuery.data.value ?? []);

const {
  name,
  desc,
  speciesIds,
  serviceIds,
  price,
  duration,
  markAsId,
  promoFrom,
  promoTo,
  sellable,
  submitted,
  serviceOptions,
  originPrice,
  totalDuration,
  savings,
  priceValid,
  toInput,
} = useComboForm(
  () => props.open,
  () => props.combo
);

const create = useCreatePetCombo();
const update = useUpdatePetCombo();
const pending = computed(() => create.isPending.value || update.isPending.value);

const submit = async () => {
  const input = toInput();
  if (!input) return;
  try {
    if (props.combo) await update.mutateAsync({ id: props.combo.id, input });
    else await create.mutateAsync(input);
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast; keep the sheet open
  }
};
</script>
