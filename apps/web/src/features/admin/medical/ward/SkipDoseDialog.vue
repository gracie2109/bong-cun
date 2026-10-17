<template>
  <AppDialog
    :open="open"
    :title="$t('medical.ward.skipTitle')"
    :ok-text="$t('medical.ward.skip')"
    :ok-disabled="!reason.trim()"
    :busy="busy"
    form-id="skip-dose-form"
    size="sm"
    @update:open="emit('update:open', $event)"
  >
    <form id="skip-dose-form" class="space-y-1.5" @submit.prevent="submit">
      <Label for="skip-reason">{{ $t("medical.ward.skipReason") }}</Label>
      <Input id="skip-reason" v-model="reason" />
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useSkipDose } from "@/features/admin/medical/queries/inpatient";

const props = defineProps<{ open: boolean; doseId: string | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const skip = useSkipDose();
const busy = skip.isPending;
const reason = ref("");
watch(() => props.open, (isOpen) => isOpen && (reason.value = ""));

const submit = async () => {
  if (!props.doseId || !reason.value.trim()) return;
  try {
    await skip.mutateAsync({ id: props.doseId, reason: reason.value.trim() });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
