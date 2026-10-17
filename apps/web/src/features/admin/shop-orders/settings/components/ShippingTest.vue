<template>
  <div class="flex flex-wrap items-center gap-3">
    <Button type="button" variant="outline" size="sm" :disabled="!ready || state.status === 'loading'" @click="run">
      <Loader2 v-if="state.status === 'loading'" class="mr-1 size-4 animate-spin" />
      {{ $t("shop.settings.testFee") }}
    </Button>
    <p v-if="!ready" class="text-xs text-muted-foreground">{{ $t("shop.settings.testNeedsWarehouse") }}</p>
    <p v-else-if="state.status === 'ok'" class="text-sm text-green-700">
      {{ $t("shop.settings.testOk", { fee: state.fee }) }}
      <span v-if="state.leadtime"> · {{ $t("shop.settings.testLeadtime", { date: state.leadtime }) }}</span>
    </p>
    <p v-else-if="state.status === 'error'" class="text-sm text-red-600">{{ $t("shop.settings.testFail") }}</p>
  </div>
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import { Loader2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useShippingTest } from "@/features/admin/shop-orders/composables/useShippingTest";
import type { GhnLocation } from "@bongcun/core/shop";

const props = defineProps<{ from: GhnLocation }>();
const { state, ready, run } = useShippingTest(toRef(props, "from"));
</script>
