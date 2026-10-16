<template>
  <AppDialog
    :open="open"
    :title="$t('pos.shift.openTitle')"
    :description="$t('pos.shift.openSubtitle', { branch: branchName })"
    :ok-text="$t('pos.shift.open')"
    :busy="mutation.isPending.value"
    form-id="open-shift-form"
    @update:open="emit('update:open', $event)"
  >
    <form id="open-shift-form" class="space-y-4" @submit.prevent="submit">
      <div class="space-y-2">
        <Label for="opening-cash">{{ $t("pos.shift.openingCash") }}</Label>
        <Input id="opening-cash" v-model="openingCash" inputmode="numeric" placeholder="0" />
        <p class="text-xs text-muted-foreground">{{ money(parseAmount(openingCash)) }}</p>
      </div>
      <div class="space-y-2">
        <Label for="open-note">{{ $t("pos.shift.note") }}</Label>
        <Input id="open-note" v-model="note" />
      </div>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useOpenShift } from "@/queries/pos";
import { money, parseAmount } from "../format";

const props = defineProps<{ open: boolean; branchId: string; branchName: string }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const openingCash = ref("");
const note = ref("");
const mutation = useOpenShift();

watch(
  () => props.open,
  (open) => {
    if (open) {
      openingCash.value = "";
      note.value = "";
    }
  }
);

const submit = async () => {
  try {
    await mutation.mutateAsync({
      branchId: props.branchId,
      openingCash: parseAmount(openingCash.value),
      note: note.value.trim(),
    });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
