<template>
  <Sheet :open="!!orderId" @update:open="(open) => !open && emit('close')">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle class="flex items-center gap-2">
          {{ order?.code ?? $t("shop.admin.detail") }}
          <OrderStatusBadge v-if="order" :status="order.status" />
        </SheetTitle>
        <SheetDescription>{{ order ? dateTime(order.placedAt) : "" }}</SheetDescription>
      </SheetHeader>

      <div class="flex-1 space-y-5 overflow-y-auto px-6 py-5">
        <Skeleton v-if="loading" class="h-60 w-full" />
        <template v-else-if="order">
          <OrderDetailInfo :order="order" />
          <OrderDetailLines :order="order" />
          <OrderDetailTimeline :events="order.events" />
        </template>
      </div>

      <SheetFooter v-if="order && actions.length" class="gap-2 border-t px-6 py-4">
        <OrderActionButtons :order="order" :actions="actions" @action="open" />
      </SheetFooter>
    </SheetContent>
  </Sheet>

  <OrderStepDialogs v-if="order" :sheet="sheet" />
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import { Sheet, SheetContent, SheetDescription, SheetFooter, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { Skeleton } from "@/components/ui/skeleton";
import { useOrderSheet } from "@/features/admin/shop-orders/composables/useOrderSheet";
import OrderStatusBadge from "@/components/common/OrderStatusBadge.vue";
import { dateTime } from "@/features/admin/pos/format";
import OrderActionButtons from "./OrderActionButtons.vue";
import OrderDetailInfo from "./OrderDetailInfo.vue";
import OrderDetailLines from "./OrderDetailLines.vue";
import OrderDetailTimeline from "./OrderDetailTimeline.vue";
import OrderStepDialogs from "./OrderStepDialogs.vue";

const props = defineProps<{ orderId: string | undefined }>();
const emit = defineEmits<{ close: [] }>();

const sheet = useOrderSheet(toRef(props, "orderId"));
const { order, loading, actions, open } = sheet;
</script>
