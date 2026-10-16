<template>
  <ul v-if="rows.length > 0" class="divide-y rounded-2xl border bg-white">
    <li v-for="row in rows" :key="row.key" class="flex gap-3 p-4">
      <span class="grid size-10 shrink-0 place-content-center rounded-full" :class="row.tone">
        <component :is="row.icon" class="size-[18px]" />
      </span>
      <span class="text-sm">
        <span class="block font-semibold">{{ $t(`client.product.delivery.${row.key}`) }}</span>
        <span class="mt-0.5 block text-muted-foreground">{{ row.text }}</span>
      </span>
    </li>
  </ul>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { Store, Truck } from "lucide-vue-next";
import { STORE_INFO } from "@/config/storeInfo";
import { formatPrice } from "@/lib/utils";
import { useShopPublicSettings } from "@/queries/shop";

/** How the item can reach the customer, from the shop's online-sale settings (the same ones checkout uses). */
const props = defineProps<{ inStoreOnly: boolean }>();

const { t } = useI18n();
const settingsQuery = useShopPublicSettings();

const rows = computed(() => {
  const settings = settingsQuery.data.value;
  if (!settings) return [];
  const list = [];
  if (props.inStoreOnly) {
    list.push({ key: "inStoreOnly", icon: Store, tone: "bg-amber-50 text-amber-800", text: t("client.product.delivery.inStoreOnlyText") });
  } else if (settings.allowCod) {
    const text = settings.freeShipFrom
      ? t("client.product.delivery.freeFrom", { amount: formatPrice(settings.freeShipFrom) })
      : t("client.product.delivery.shipText");
    list.push({ key: "ship", icon: Truck, tone: "bg-brand-soft text-primary", text });
  }
  if (settings.allowPickup) {
    const address = settings.pickupAddress ?? STORE_INFO.address;
    list.push({ key: "pickup", icon: Store, tone: "bg-sage-soft text-sage", text: t("client.product.delivery.pickupText", { address }) });
  }
  return list;
});
</script>
