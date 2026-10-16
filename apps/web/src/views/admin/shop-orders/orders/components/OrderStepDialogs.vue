<template>
  <ConfirmOrderDialog
    v-if="order"
    :open="dialog === 'confirm'"
    :order="order"
    v-model:fee="form.fee"
    :busy="busy"
    @update:open="onOpen"
    @submit="run({ step: 'confirm', id: order.id, shippingFee: parseFee(form.fee) })"
  />

  <AppDialog
    :open="dialog === 'pack'"
    :title="$t(order?.deliveryMethod === 'pickup' ? 'shop.admin.dialogs.readyTitle' : 'shop.admin.dialogs.packTitle')"
    :description="$t('shop.admin.dialogs.packHint')"
    :ok-text="$t('shop.admin.dialogs.ok')"
    :busy="busy"
    @update:open="onOpen"
    @ok="order && run({ step: 'pack', id: order.id })"
  />

  <TrackingDialog
    :open="dialog === 'ship'"
    v-model:code="form.tracking"
    :cod="cod"
    :busy="busy"
    @update:open="onOpen"
    @submit="order && run({ step: 'ship', id: order.id, trackingCode: form.tracking })"
  />

  <PickupPayDialog
    :open="dialog === 'collect'"
    :total="order?.total ?? 0"
    :busy="busy"
    @update:open="onOpen"
    @submit="(payments) => order && run({ step: 'pay', id: order.id, payments })"
  />

  <AppDialog
    :open="dialog === 'deliver'"
    :title="$t('shop.admin.dialogs.deliverTitle')"
    :description="$t('shop.admin.dialogs.deliverHint', { amount: money(cod) })"
    :ok-text="$t('shop.admin.dialogs.deliverOk')"
    :busy="busy"
    @update:open="onOpen"
    @ok="order && run({ step: 'deliver', id: order.id })"
  />

  <ReasonDialog
    :open="dialog === 'return' || dialog === 'cancel'"
    v-model:reason="form.reason"
    :kind="dialog === 'return' ? 'return' : 'cancel'"
    :busy="busy"
    @update:open="onOpen"
    @submit="order && dialog && run({ step: dialog === 'return' ? 'return' : 'cancel', id: order.id, reason: form.reason })"
  />
</template>

<script lang="ts" setup>
import { computed } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import type { useOrderSheet } from "@/composables/shop/useOrderSheet";
import { parseFee } from "@bongcun/core/shop";
import { money } from "@/views/admin/pos/format";
import ConfirmOrderDialog from "./ConfirmOrderDialog.vue";
import PickupPayDialog from "./PickupPayDialog.vue";
import ReasonDialog from "./ReasonDialog.vue";
import TrackingDialog from "./TrackingDialog.vue";

const props = defineProps<{ sheet: ReturnType<typeof useOrderSheet> }>();

const order = computed(() => props.sheet.order.value);
const dialog = computed(() => props.sheet.dialog.value);
const form = props.sheet.form;
const busy = computed(() => props.sheet.busy.value);
const cod = computed(() => props.sheet.cod.value);
const run = props.sheet.run;

/** A dialog that is dismissed (X, Esc, Cancel) closes; opening is done by the buttons. */
const onOpen = (open: boolean) => {
  if (!open) props.sheet.close();
};
</script>
