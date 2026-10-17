<template>
  <AppDialog
    :open="open"
    :title="$t('medical.ward.stopTitle', { name: order?.name ?? '' })"
    :ok-text="$t('medical.ward.stop')"
    :busy="stopping.isPending.value"
    form-id="ward-stop-form"
    size="sm"
    @update:open="emit('update:open', $event)"
  >
    <form id="ward-stop-form" class="space-y-1.5" @submit.prevent="submit">
      <p class="text-sm text-muted-foreground">{{ $t("medical.ward.stopDesc") }}</p>
      <Label for="stop-reason">{{ $t("medical.ward.reason") }}</Label>
      <Input id="stop-reason" v-model="reason" :placeholder="$t('medical.ward.reasonPlaceholder')" />
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useStopOrder } from "@/features/admin/medical/queries/inpatient";
import type { WardOrder } from "@bongcun/core/medical";

const props = defineProps<{ open: boolean; order: WardOrder | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const stopping = useStopOrder();
const reason = ref("");
watch(() => props.open, (isOpen) => isOpen && (reason.value = ""));

const submit = async () => {
  if (!props.order) return;
  try {
    await stopping.mutateAsync({ id: props.order.id, reason: reason.value });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
