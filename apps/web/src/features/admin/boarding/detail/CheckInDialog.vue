<template>
  <AppDialog
    :open="open"
    :title="$t('boarding.checkIn.title', { code: stay.code })"
    :description="$t('boarding.checkIn.subtitle')"
    :ok-text="$t('boarding.detail.checkIn')"
    :ok-disabled="!complete"
    :busy="checkingIn.isPending.value"
    form-id="boarding-check-in-form"
    size="lg"
    persistent
    @update:open="emit('update:open', $event)"
  >
    <form id="boarding-check-in-form" class="space-y-4" @submit.prevent="submit">
      <PetHealthFlagsBanner :pets="flagPets" />
      <section v-for="draft in drafts" :key="draft.stayPetId" class="space-y-3 rounded-lg border p-3">
        <p class="text-sm font-semibold">{{ draft.petName }}</p>
        <div class="grid gap-3 sm:grid-cols-2">
          <div class="space-y-1.5">
            <Label :for="`weight-${draft.stayPetId}`">{{ $t("boarding.checkIn.weight") }}</Label>
            <Input :id="`weight-${draft.stayPetId}`" v-model="draft.weight" inputmode="decimal" placeholder="kg" />
            <p v-if="isOverweight(draft, types)" class="text-xs font-semibold text-amber-700">{{ $t("boarding.dialog.overweight") }}</p>
          </div>
          <div class="space-y-1.5">
            <Label :for="`vaccine-note-${draft.stayPetId}`">{{ $t("boarding.checkIn.vaccineNote") }}</Label>
            <Input :id="`vaccine-note-${draft.stayPetId}`" v-model="draft.vaccineNote" />
          </div>
        </div>
        <label class="flex items-center gap-2 text-sm">
          <Checkbox :checked="draft.vaccineChecked" @update:checked="(value: boolean | 'indeterminate') => (draft.vaccineChecked = value === true)" />
          {{ $t("boarding.checkIn.vaccineSeen") }}
        </label>
        <p v-if="!draft.vaccineChecked" class="text-xs font-semibold text-amber-700">{{ $t("boarding.checkIn.vaccineWarn") }}</p>
        <div class="grid gap-3 sm:grid-cols-3">
          <div class="space-y-1.5">
            <Label>{{ $t("boarding.dialog.belongings") }}</Label>
            <Textarea v-model="draft.belongings" rows="2" :placeholder="$t('boarding.dialog.belongingsHint')" />
          </div>
          <div class="space-y-1.5">
            <Label>{{ $t("boarding.dialog.feeding") }}</Label>
            <Textarea v-model="draft.feeding" rows="2" :placeholder="$t('boarding.dialog.feedingHint')" />
          </div>
          <div class="space-y-1.5">
            <Label>{{ $t("boarding.dialog.medication") }}</Label>
            <Textarea v-model="draft.medication" rows="2" />
          </div>
        </div>
      </section>

      <div class="space-y-1.5">
        <Label for="check-in-emergency">{{ $t("boarding.dialog.emergencyPhone") }}</Label>
        <Input id="check-in-emergency" v-model="emergencyPhone" inputmode="tel" />
      </div>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import PetHealthFlagsBanner from "@/features/admin/medical/flags/PetHealthFlagsBanner.vue";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { useCheckInBoarding } from "@/queries/boarding";
import type { BoardingStay } from "@bongcun/core/boarding";
import { useKennelTypeOptions } from "../useKennelTypeOptions";
import { checkInDraftOf, isCheckInComplete, isOverweight, toCheckInInput, type CheckInPetDraft } from "./checkInDraft";

const props = defineProps<{ open: boolean; stay: BoardingStay }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const checkingIn = useCheckInBoarding();
const types = useKennelTypeOptions(computed(() => props.stay.branchId));

const drafts = ref<CheckInPetDraft[]>([]);
const emergencyPhone = ref("");

// Start from what was booked every time the dialog opens.
watch(
  () => props.open,
  (open) => {
    if (!open) return;
    drafts.value = props.stay.pets.filter((pet) => pet.status === "active").map(checkInDraftOf);
    emergencyPhone.value = props.stay.emergencyPhone ?? "";
  },
  { immediate: true }
);

const flagPets = computed(() => props.stay.pets.filter((pet) => pet.status === "active").map((pet) => ({ id: pet.petId, name: pet.petName })));
const complete = computed(() => isCheckInComplete(drafts.value));

const submit = async () => {
  if (!complete.value) return;
  try {
    await checkingIn.mutateAsync({ id: props.stay.id, pets: drafts.value.map(toCheckInInput), emergencyPhone: emergencyPhone.value });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
