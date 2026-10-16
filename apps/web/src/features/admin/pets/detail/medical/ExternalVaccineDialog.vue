<template>
  <AppDialog
    :open="open"
    :title="$t('medical.book.addExternal')"
    :description="$t('medical.book.externalDesc')"
    :ok-text="$t('petCare.common.save')"
    :ok-disabled="!valid"
    :busy="saving"
    form-id="medical-external-form"
    size="md"
    @update:open="emit('update:open', $event)"
  >
    <form id="medical-external-form" class="space-y-4" @submit.prevent="submit">
      <div class="space-y-1.5">
        <Label>{{ $t("medical.book.type") }}</Label>
        <VaccineTypeSelect v-model="draft.typeId" :types="types" />
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <div class="space-y-1.5">
          <Label for="ext-given">{{ $t("medical.book.givenOn") }}</Label>
          <Input id="ext-given" v-model="draft.givenOn" type="date" :max="todayKey()" />
        </div>
        <div class="space-y-1.5">
          <Label for="ext-place">{{ $t("medical.book.place") }}</Label>
          <Input id="ext-place" v-model="draft.place" />
        </div>
        <div class="space-y-1.5">
          <Label for="ext-lot">{{ $t("medical.book.lotNo") }}</Label>
          <Input id="ext-lot" v-model="draft.lotNo" />
        </div>
        <div class="space-y-1.5">
          <Label for="ext-exp">{{ $t("medical.book.expiry") }}</Label>
          <Input id="ext-exp" v-model="draft.expiryDate" type="date" />
        </div>
        <div class="space-y-1.5">
          <Label for="ext-dose">{{ $t("medical.book.doseNo") }}</Label>
          <Input id="ext-dose" v-model="draft.doseNo" inputmode="numeric" />
        </div>
        <div class="space-y-1.5">
          <Label for="ext-due">{{ $t("medical.book.nextDue") }}</Label>
          <Input id="ext-due" v-model="draft.nextDueOn" type="date" @input="draft.dueEdited = true" />
        </div>
      </div>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAddExternalVaccine } from "@/queries/vaccinations";
import type { VaccineBookEntry } from "@bongcun/core/medical";
import VaccineTypeSelect from "@/features/admin/medical/book/VaccineTypeSelect.vue";
import { useVaccineTypeOptions } from "@/features/admin/medical/book/useVaccineTypeOptions";
import { todayKey } from "@/features/admin/medical/format";
import { nextDue, suggestedDoseNo } from "@/features/admin/medical/nextDue";
import { emptyExternalDraft, toExternalInput, type ExternalDraft } from "./externalDraft";

const props = defineProps<{ open: boolean; petId: string; book: VaccineBookEntry[] }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const draft = ref<ExternalDraft>(emptyExternalDraft());
watch(() => props.open, (isOpen) => isOpen && (draft.value = emptyExternalDraft()));

const types = useVaccineTypeOptions();
const type = computed(() => types.value.find((item) => item.id === draft.value.typeId));

watch(() => draft.value.typeId, (typeId) => {
  if (typeId) draft.value.doseNo = String(suggestedDoseNo(typeId, props.book));
  draft.value.dueEdited = false;
});
watch(
  () => [draft.value.typeId, draft.value.doseNo, draft.value.givenOn, type.value] as const,
  () => {
    if (!draft.value.dueEdited) draft.value.nextDueOn = nextDue(type.value, Number(draft.value.doseNo) || 1, draft.value.givenOn) ?? "";
  }
);

const valid = computed(() => !!draft.value.typeId && !!draft.value.givenOn && draft.value.givenOn <= todayKey());

const mutation = useAddExternalVaccine();
const saving = computed(() => mutation.isPending.value);

const submit = async () => {
  if (!valid.value || saving.value) return;
  try {
    await mutation.mutateAsync({ petId: props.petId, input: toExternalInput(draft.value) });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
