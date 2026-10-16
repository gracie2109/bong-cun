<template>
  <div class="space-y-4">
    <dl class="grid grid-cols-[7rem_1fr] gap-y-1.5 text-sm">
      <dt class="text-muted-foreground">{{ $t("shop.admin.cols.customer") }}</dt>
      <dd>{{ order.receiverName }} · {{ order.receiverPhone }}</dd>
      <dt class="text-muted-foreground">{{ $t("shop.admin.cols.method") }}</dt>
      <dd>{{ $t(`shop.checkout.methods.${order.deliveryMethod}`) }} · {{ $t(`shop.checkout.payment.${order.deliveryMethod}`) }}</dd>
      <template v-if="order.deliveryMethod === 'delivery'">
        <dt class="text-muted-foreground">{{ $t("shop.admin.address") }}</dt>
        <dd class="flex items-start gap-2">
          <span class="min-w-0 flex-1">{{ address }}</span>
          <button type="button" class="shrink-0 text-primary hover:underline" @click="copy">
            <Copy class="inline size-3.5" /> {{ $t("shop.admin.copy") }}
          </button>
        </dd>
        <dt class="text-muted-foreground">{{ $t("shop.admin.weight") }}</dt>
        <dd>{{ order.weightG.toLocaleString("vi-VN") }} g</dd>
      </template>
      <template v-if="order.customerNote">
        <dt class="text-muted-foreground">{{ $t("shop.checkout.note") }}</dt>
        <dd>{{ order.customerNote }}</dd>
      </template>
      <template v-if="order.trackingCode">
        <dt class="text-muted-foreground">{{ $t("shop.admin.cols.tracking") }}</dt>
        <dd>
          <a :href="trackingUrl(order.trackingCode)" target="_blank" rel="noopener" class="font-mono text-primary hover:underline">
            {{ order.trackingCode }}
          </a>
        </dd>
      </template>
      <template v-if="order.invoice">
        <dt class="text-muted-foreground">{{ $t("shop.admin.invoice") }}</dt>
        <dd>{{ order.invoice.code }} · {{ $t(`pos.status.${order.invoice.status}`) }}</dd>
      </template>
      <template v-if="order.cancelReason">
        <dt class="text-muted-foreground">{{ $t("shop.admin.reason") }}</dt>
        <dd class="text-red-700">{{ order.cancelReason }}</dd>
      </template>
    </dl>

    <dl class="space-y-1.5 border-t pt-3 text-sm">
      <div class="flex justify-between">
        <dt class="text-muted-foreground">{{ $t("shop.cart.subtotal") }}</dt>
        <dd>{{ money(order.subtotal) }}</dd>
      </div>
      <div v-if="order.deliveryMethod === 'delivery'" class="flex justify-between">
        <dt class="text-muted-foreground">
          {{ $t("shop.cart.shipping") }}
          <span v-if="order.shippingFee === null" class="text-xs">({{ $t("shop.admin.estimate") }})</span>
        </dt>
        <dd>{{ money(order.shippingFee ?? order.shippingFeeQuote) }}</dd>
      </div>
      <div class="flex justify-between text-base font-semibold">
        <dt>{{ order.deliveryMethod === "delivery" ? $t("shop.admin.codTotal") : $t("shop.cart.total") }}</dt>
        <dd class="text-primary">{{ money(order.total) }}</dd>
      </div>
    </dl>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Copy } from "lucide-vue-next";
import { toast } from "vue-sonner";
import i18n from "@/i18n";
import type { AdminOrder } from "@bongcun/core/shop";
import { formatAddress } from "@bongcun/core/shop";
import { copyableAddress, trackingUrl } from "@bongcun/core/shop";
import { money } from "@/features/admin/pos/format";

const props = defineProps<{ order: AdminOrder }>();

const address = computed(() =>
  formatAddress({
    street: props.order.shipStreet ?? "",
    wardName: props.order.shipWardName ?? "",
    districtName: props.order.shipDistrictName ?? "",
    provinceName: props.order.shipProvinceName ?? "",
  })
);

const copy = async () => {
  try {
    await navigator.clipboard.writeText(copyableAddress(props.order));
    toast.success(i18n.global.t("shop.admin.copied"));
  } catch {
    toast.error(i18n.global.t("shop.admin.errors.generic"));
  }
};
</script>
