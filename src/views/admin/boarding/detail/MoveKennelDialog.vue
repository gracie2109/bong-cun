<template>
  <AppDialog
    :open="open"
    :title="$t('boarding.move.title', { name: pet.petName })"
    :description="$t('boarding.move.subtitle', { code: pet.kennelCode, type: pet.kennelTypeName })"
    :ok-text="$t('boarding.move.ok')"
    :ok-disabled="!kennelId"
    :busy="moving.isPending.value"
    form-id="boarding-move-form"
    size="sm"
    persistent
    @update:open="emit('update:open', $event)"
  >
    <form id="boarding-move-form" class="space-y-3" @submit.prevent="submit">
      <div class="space-y-1.5">
        <Label>{{ $t("boarding.move.kennel") }}</Label>
        <Select v-model="kennelId">
          <SelectTrigger><SelectValue :placeholder="$t('boarding.move.pick')" /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="kennel in choices" :key="kennel.id" :value="kennel.id">
              {{ kennel.code }}<span v-if="kennel.status !== 'ready'"> · {{ $t(`boarding.kennelStatus.${kennel.status}`) }}</span>
            </SelectItem>
          </SelectContent>
        </Select>
        <p v-if="!choices.length" class="text-xs text-amber-700">{{ $t("boarding.move.none") }}</p>
      </div>
      <p class="text-xs text-muted-foreground">{{ $t("boarding.move.hint") }}</p>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useKennels, useMoveBoardingPet } from "@/queries/boarding";
import type { BoardingStay, StayPet } from "@/types/boarding";

const FIRST_PAGE = { pageIndex: 1, pageSize: 100 };

const props = defineProps<{ open: boolean; stay: BoardingStay; pet: StayPet }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const moving = useMoveBoardingPet();
const kennelId = ref("");
watch(
  () => props.open,
  (open) => open && (kennelId.value = "")
);

const kennelsQuery = useKennels(
  computed(() => (props.open ? props.stay.branchId : undefined)),
  FIRST_PAGE,
  computed(() => ({ typeId: props.pet.kennelTypeId }))
);
// Another kennel of the same type; a pet that is in the hotel needs one that is ready.
const choices = computed(() =>
  (kennelsQuery.data.value?.rows ?? []).filter(
    (kennel) =>
      kennel.isActive &&
      kennel.id !== props.pet.kennelId &&
      kennel.status !== "maintenance" &&
      (props.stay.status !== "checked_in" || kennel.status === "ready")
  )
);

const submit = async () => {
  if (!kennelId.value) return;
  try {
    await moving.mutateAsync({ stayPetId: props.pet.id, kennelId: kennelId.value });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
