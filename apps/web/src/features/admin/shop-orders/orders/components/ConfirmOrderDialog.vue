<template>
  <AppDialog
    v-model:open="open"
    :title="$t('shop.admin.dialogs.confirmTitle')"
    :description="$t(order.deliveryMethod === 'delivery' ? 'shop.admin.dialogs.confirmHint' : 'shop.admin.dialogs.confirmPickupHint')"
    :ok-text="$t('shop.admin.dialogs.confirmOk')"
    :busy="busy"
    @ok="$emit('submit')"
  >
    <div v-if="order.deliveryMethod === 'delivery'" class="space-y-3">
      <p class="text-sm text-muted-foreground">{{ $t("shop.admin.dialogs.estimate", { fee: money(order.shippingFeeQuote) }) }}</p>
      <div class="space-y-1.5">
        <Label for="confirm-fee">{{ $t("shop.admin.dialogs.fee") }}</Label>
        <div class="flex gap-2">
          <Input id="confirm-fee" v-model="fee" inputmode="numeric" />
          <Button type="button" variant="outline" :disabled="!quote.ready.value || quote.loading.value" @click="quote.run()">
            <Loader2 v-if="quote.loading.value" class="mr-1 size-4 animate-spin" />
            {{ $t("shop.admin.dialogs.requote") }}
          </Button>
        </div>
        <p v-if="!quote.ready.value" class="text-xs text-muted-foreground">{{ $t("shop.admin.dialogs.noWarehouse") }}</p>
        <p v-else-if="quote.failed.value" class="text-xs text-red-600">{{ $t(`shop.admin.dialogs.quoteFailed.${quote.failed.value}`) }}</p>
      </div>
      <p v-if="warn" class="rounded-lg bg-amber-50 p-2 text-sm text-amber-900">{{ $t("shop.admin.dialogs.feeWarn") }}</p>
      <p class="flex justify-between text-sm font-semibold">
        <span>{{ $t("shop.admin.codTotal") }}</span>
        <span class="text-primary">{{ money(order.subtotal + (parseFee(fee) ?? order.shippingFeeQuote)) }}</span>
      </p>
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, toRef } from "vue";
import { Loader2 } from "lucide-vue-next";
import AppDialog from "@/components/common/AppDialog.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useOrderFeeQuote } from "@/features/admin/shop-orders/composables/useOrderFeeQuote";
import type { AdminOrder } from "@bongcun/core/shop";
import { parseFee } from "@bongcun/core/shop";
import { shouldWarnFeeChange } from "@bongcun/core/shop";
import { money } from "@/features/admin/pos/format";

const props = defineProps<{ order: AdminOrder; busy: boolean }>();
const open = defineModel<boolean>("open", { required: true });
const fee = defineModel<string>("fee", { required: true });
defineEmits<{ submit: [] }>();

const quote = useOrderFeeQuote(toRef(props, "order"), (value) => (fee.value = String(value)));
const warn = computed(() => shouldWarnFeeChange(props.order.shippingFeeQuote, parseFee(fee.value) ?? props.order.shippingFeeQuote));
</script>
