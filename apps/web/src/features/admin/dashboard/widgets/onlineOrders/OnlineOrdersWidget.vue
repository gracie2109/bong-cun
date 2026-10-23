<template>
  <WidgetCard
    :title="$t('dashboard.online.title')"
    :icon="ShoppingBag"
    :state="state"
    :to="{ name: 'shopOrders' }"
    :link-label="$t('dashboard.online.open')"
    :empty-text="$t('dashboard.online.empty')"
    @retry="refetch()"
  >
    <dl class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <div v-for="status in ONLINE_ORDER_STATUSES" :key="status">
        <dt class="text-xs text-muted-foreground">{{ $t(`dashboard.online.status.${status}`) }}</dt>
        <dd class="text-xl font-bold" :class="status === 'pending' && countOf(counts, status) > 0 && 'text-amber-600'">
          {{ countOf(counts, status) }}
        </dd>
      </div>
    </dl>
  </WidgetCard>
</template>

<script lang="ts" setup>
import { ShoppingBag } from "lucide-vue-next";
import WidgetCard from "../../kit/WidgetCard.vue";
import { countOf, ONLINE_ORDER_STATUSES } from "./onlineOrders";
import { useOnlineOrders } from "./useOnlineOrders";

const { state, counts, refetch } = useOnlineOrders();
</script>
