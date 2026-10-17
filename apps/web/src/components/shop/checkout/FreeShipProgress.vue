<template>
  <div v-if="threshold" class="rounded-2xl bg-sage-soft p-4 text-sm">
    <p class="flex items-center gap-2 font-medium text-sage">
      <Truck class="size-4 shrink-0" />
      <span v-if="left > 0">{{ $t("shop.freeShip.left", { amount: formatPrice(left) }) }}</span>
      <span v-else>{{ $t("shop.freeShip.reached") }}</span>
    </p>
    <div class="mt-3 h-1.5 overflow-hidden rounded-full bg-white" aria-hidden="true">
      <div class="h-full rounded-full bg-sage transition-[width] duration-700 ease-out-quart" :style="{ width: `${progress}%` }" />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Truck } from "lucide-vue-next";
import { formatPrice } from "@/lib/utils";
import { useShopPublicSettings } from "@/features/shared/shop/queries/shop";

/** "Buy X more for free delivery", from the shop's free-shipping threshold; hidden when there is none. */
const props = defineProps<{ subtotal: number }>();

const settingsQuery = useShopPublicSettings();
const threshold = computed(() => (settingsQuery.data.value?.allowCod ? settingsQuery.data.value.freeShipFrom : null));
const left = computed(() => Math.max(0, (threshold.value ?? 0) - props.subtotal));
const progress = computed(() => (threshold.value ? Math.min(100, (props.subtotal / threshold.value) * 100) : 0));
</script>
