<template>
  <AppDialog
    :open="open"
    :title="$t('boarding.extend.title', { code: stay.code })"
    :description="$t('boarding.extend.subtitle')"
    :ok-text="$t('petCare.common.save')"
    :ok-disabled="!valid"
    :busy="extending.isPending.value"
    form-id="boarding-extend-form"
    size="sm"
    persistent
    @update:open="emit('update:open', $event)"
  >
    <form id="boarding-extend-form" class="space-y-3" @submit.prevent="submit">
      <div class="space-y-1.5">
        <Label for="extend-date">{{ $t("boarding.dialog.departure") }}</Label>
        <div class="flex gap-2">
          <Input id="extend-date" v-model="outDate" type="date" :min="todayKey()" />
          <Input v-model="outTime" type="time" step="900" class="w-32" :aria-label="$t('boarding.dialog.departureTime')" />
        </div>
      </div>
      <p class="text-xs text-muted-foreground">{{ $t("boarding.extend.hint") }}</p>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useExtendBoardingStay } from "@/queries/boarding";
import type { BoardingStay } from "@/types/boarding";
import { dateKeyOf, timeOf, todayKey, toIso } from "../format";

const props = defineProps<{ open: boolean; stay: BoardingStay }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const extending = useExtendBoardingStay();
const outDate = ref("");
const outTime = ref("");

watch(
  () => props.open,
  (open) => {
    if (!open) return;
    outDate.value = dateKeyOf(props.stay.plannedOutAt);
    outTime.value = timeOf(props.stay.plannedOutAt);
  },
  { immediate: true }
);

const valid = computed(() => !!outDate.value && !!outTime.value);

const submit = async () => {
  if (!valid.value) return;
  try {
    await extending.mutateAsync({ id: props.stay.id, plannedOutAt: toIso(outDate.value, outTime.value) });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
