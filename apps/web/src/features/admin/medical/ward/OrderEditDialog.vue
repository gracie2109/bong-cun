<template>
  <AppDialog
    :open="open"
    :title="$t('medical.ward.editTitle', { name: order?.name ?? '' })"
    :ok-text="$t('petCare.common.save')"
    :ok-disabled="!valid"
    :busy="updating.isPending.value"
    form-id="ward-order-edit-form"
    size="lg"
    @update:open="emit('update:open', $event)"
  >
    <form v-if="order" id="ward-order-edit-form" class="space-y-4" @submit.prevent="submit">
      <p class="rounded-lg border bg-muted/40 px-3 py-2 text-sm">
        <span class="font-semibold">{{ order.name }}</span>
        <span class="block text-xs text-muted-foreground">{{ $t("medical.ward.editFixed") }}</span>
      </p>

      <div class="grid gap-3 sm:grid-cols-2">
        <div v-if="order.kind !== 'care'" class="space-y-1.5">
          <Label for="edit-qty">{{ $t("medical.ward.qtyPerDose") }}</Label>
          <Input id="edit-qty" v-model.number="draft.qtyPerDose" type="number" min="0.01" step="any" />
          <p class="text-xs text-muted-foreground">{{ $t("medical.ward.qtyHint") }}</p>
        </div>
        <div class="space-y-1.5" :class="order.kind === 'care' && 'sm:col-span-2'">
          <Label for="edit-dose">{{ $t("medical.ward.dose") }}</Label>
          <Input id="edit-dose" v-model="draft.dose" :placeholder="$t('medical.ward.dosePlaceholder')" />
        </div>
        <div class="space-y-1.5">
          <Label for="edit-start">{{ $t("medical.ward.startOn") }}</Label>
          <Input id="edit-start" v-model="draft.startOn" type="date" :disabled="!startEditable" />
        </div>
        <div class="space-y-1.5">
          <Label for="edit-end">{{ $t("medical.ward.endOn") }}</Label>
          <Input id="edit-end" v-model="draft.endOn" type="date" :min="todayKey()" />
        </div>
      </div>

      <OrderHoursField v-model="draft.times" />
      <p class="text-xs text-muted-foreground">{{ $t("medical.ward.editDosesHint") }}</p>

      <div class="grid gap-3 sm:grid-cols-2">
        <div class="space-y-1.5">
          <Label for="edit-note">{{ $t("medical.ward.note") }}</Label>
          <Input id="edit-note" v-model="draft.note" />
        </div>
        <div class="space-y-1.5">
          <Label for="edit-reason">{{ $t("medical.ward.reason") }}</Label>
          <Input id="edit-reason" v-model="draft.reason" :placeholder="$t('medical.ward.reasonPlaceholder')" />
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
import { todayKey } from "@/features/admin/schedule/format";
import { useUpdateOrder } from "@/queries/inpatient";
import type { WardOrder } from "@bongcun/core/medical";
import OrderHoursField from "./OrderHoursField.vue";
import { canEditStart, editDraftFromOrder, hasOrderChanges, isEditDraftValid, toUpdateInput, type OrderEditDraft } from "./orderEditDraft";

const props = defineProps<{ open: boolean; order: WardOrder | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const updating = useUpdateOrder();
const draft = ref<OrderEditDraft>(editDraftFromOrder({ kind: "care", times: [] } as unknown as WardOrder));
watch(
  () => [props.open, props.order] as const,
  ([isOpen, order]) => isOpen && order && (draft.value = editDraftFromOrder(order)),
  { immediate: true }
);

const startEditable = computed(() => !!props.order && canEditStart(props.order));
const valid = computed(() => !!props.order && isEditDraftValid(props.order, draft.value));

const submit = async () => {
  if (!props.order || !valid.value) return;
  const input = toUpdateInput(props.order, draft.value);
  if (!hasOrderChanges(input)) {
    emit("update:open", false);
    return;
  }
  try {
    await updating.mutateAsync({ id: props.order.id, input });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
