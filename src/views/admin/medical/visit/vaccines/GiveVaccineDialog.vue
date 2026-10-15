<template>
  <AppDialog
    :open="open"
    :title="$t('medical.book.giveTitle')"
    :description="$t('medical.book.giveDesc')"
    :ok-text="$t('medical.book.give')"
    :ok-disabled="!valid"
    :busy="saving"
    form-id="medical-give-form"
    size="md"
    @update:open="emit('update:open', $event)"
  >
    <form id="medical-give-form" class="space-y-4" @submit.prevent="submit">
      <div class="space-y-1.5">
        <Label>{{ $t("medical.book.type") }}</Label>
        <VaccineTypeSelect v-model="draft.typeId" :types="types" />
      </div>

      <div v-if="needsLot" class="space-y-1.5">
        <Label>{{ $t("medical.book.lotLabel") }}</Label>
        <Select v-model="draft.lotId">
          <SelectTrigger :aria-label="$t('medical.book.lotLabel')"><SelectValue :placeholder="$t('medical.book.lotPlaceholder')" /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="lot in lots" :key="lot.id" :value="lot.id">
              {{ lot.lotNo || "-" }} · {{ lot.expiryDate ?? $t("medical.book.noExpiry") }} · {{ lot.qtyOnHand }}
            </SelectItem>
          </SelectContent>
        </Select>
        <p v-if="noLots" class="text-xs text-red-600">{{ $t("medical.book.noLots") }}</p>
      </div>

      <div class="grid gap-3 sm:grid-cols-2">
        <div class="space-y-1.5">
          <Label for="give-dose">{{ $t("medical.book.doseNo") }}</Label>
          <Input id="give-dose" v-model="draft.doseNo" inputmode="numeric" />
        </div>
        <div class="space-y-1.5">
          <Label for="give-due">{{ $t("medical.book.nextDue") }}</Label>
          <Input id="give-due" v-model="draft.nextDueOn" type="date" @input="draft.dueEdited = true" />
        </div>
      </div>
      <p v-if="type" class="text-xs text-muted-foreground">
        {{ $t("medical.book.protocol", { doses: type.seriesDoses, interval: type.seriesIntervalDays ?? "-", booster: type.boosterIntervalDays ?? "-" }) }}
      </p>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { VaccineBookEntry } from "@/types/vaccination";
import VaccineTypeSelect from "../../book/VaccineTypeSelect.vue";
import { useGiveVaccine } from "./useGiveVaccine";

const props = defineProps<{ open: boolean; visitId: string; branchId: string; book: VaccineBookEntry[] }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const { draft, types, type, needsLot, noLots, lots, valid, saving, submit } = useGiveVaccine({
  open: toRef(props, "open"),
  visitId: toRef(props, "visitId"),
  branchId: toRef(props, "branchId"),
  book: toRef(props, "book"),
  close: () => emit("update:open", false),
});
</script>
