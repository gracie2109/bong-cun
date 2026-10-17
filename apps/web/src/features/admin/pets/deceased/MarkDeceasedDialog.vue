<template>
  <AppDialog
    :open="open"
    :title="$t('petCare.pets.deceased.title', { name: pet.name })"
    :ok-text="$t('petCare.pets.deceased.confirm')"
    :ok-disabled="!state.canSubmit.value"
    :busy="state.busy.value"
    form-id="mark-deceased-form"
    danger
    size="md"
    @update:open="emit('update:open', $event)"
  >
    <form id="mark-deceased-form" class="space-y-4" @submit.prevent="submit">
      <p class="text-sm text-muted-foreground">{{ $t("petCare.pets.deceased.desc") }}</p>

      <Skeleton v-if="state.preview.isPending.value" class="h-24 w-full" />
      <DeceasedImpactList
        v-else-if="state.data.value"
        :preview="state.data.value"
        :blocked="state.blocked.value"
        :cancel-count="state.cancelCount.value"
      />

      <div class="grid gap-3 sm:grid-cols-[11rem_1fr]">
        <div class="space-y-1.5">
          <Label for="deceased-on">{{ $t("petCare.pets.deceased.date") }}</Label>
          <Input id="deceased-on" v-model="state.deceasedOn.value" type="date" :max="todayInput()" :min="pet.birthDate ?? undefined" />
        </div>
        <div class="space-y-1.5">
          <Label for="deceased-note">{{ $t("petCare.pets.deceased.note") }}</Label>
          <Input id="deceased-note" v-model="state.note.value" :placeholder="$t('petCare.pets.deceased.notePlaceholder')" />
        </div>
      </div>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, toRef } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import type { PetProfile } from "@bongcun/supabase/pets";
import { todayInput } from "../format";
import DeceasedImpactList from "./DeceasedImpactList.vue";
import { useMarkDeceased } from "./useMarkDeceased";

const props = defineProps<{ open: boolean; pet: PetProfile }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const state = useMarkDeceased(
  computed(() => props.pet.id),
  toRef(props, "open"),
  computed(() => props.pet.birthDate)
);

const submit = async () => {
  if (await state.submit()) emit("update:open", false);
};
</script>
