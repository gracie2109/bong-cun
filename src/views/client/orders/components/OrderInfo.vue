<template>
  <aside class="space-y-4 rounded-xl border bg-white p-5">
    <div class="space-y-1 text-sm">
      <p class="font-semibold">{{ $t(order.deliveryMethod === "delivery" ? "shop.order.receiver" : "shop.order.pickupBy") }}</p>
      <p>{{ order.receiverName }} · {{ order.receiverPhone }}</p>
      <p v-if="order.deliveryMethod === 'delivery'" class="text-muted-foreground">
        {{ formatAddress({ street: order.shipStreet ?? "", wardName: order.shipWardName ?? "", districtName: order.shipDistrictName ?? "", provinceName: order.shipProvinceName ?? "" }) }}
      </p>
      <p v-if="order.customerNote" class="text-muted-foreground">{{ $t("shop.checkout.note") }}: {{ order.customerNote }}</p>
    </div>

    <dl class="space-y-2 border-t pt-4 text-sm">
      <div class="flex justify-between">
        <dt class="text-muted-foreground">{{ $t("shop.cart.subtotal") }}</dt>
        <dd class="font-medium">{{ formatPrice(order.subtotal) }}</dd>
      </div>
      <div class="flex justify-between gap-3">
        <dt class="text-muted-foreground">{{ $t("shop.cart.shipping") }}</dt>
        <dd class="text-right font-medium">
          <template v-if="order.deliveryMethod === 'pickup'">{{ $t("shop.checkout.noShipping") }}</template>
          <template v-else>
            {{ formatPrice(orderShippingFee(order)) }}
            <span v-if="order.shippingFee === null" class="block text-xs font-normal text-muted-foreground">
              {{ $t("shop.order.feePending") }}
            </span>
          </template>
        </dd>
      </div>
    </dl>
    <p v-if="feeWentUp" class="rounded-lg bg-amber-50 p-3 text-sm text-amber-900">{{ $t("shop.order.feeWentUp") }}</p>

    <div class="flex items-baseline justify-between border-t pt-4">
      <span class="font-semibold">{{ $t("shop.cart.total") }}</span>
      <span class="text-2xl font-bold text-primary">{{ formatPrice(order.total) }}</span>
    </div>
    <p class="text-sm text-muted-foreground">
      {{ $t(`shop.checkout.payment.${order.deliveryMethod}`) }} ·
      {{ $t(`shop.order.payment.${order.paymentStatus}`) }}
    </p>
  </aside>
</template>

<script lang="ts" setup>
import { formatPrice } from "@/lib/utils";
import type { ShopOrderDetail } from "@/types/shopOrder";
import { formatAddress } from "@/utils/shop/address";
import { orderShippingFee } from "@/utils/shop/order";

defineProps<{ order: ShopOrderDetail; feeWentUp: boolean }>();
</script>
