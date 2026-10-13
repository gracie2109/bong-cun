<template>
  <Button
    v-for="action in actions"
    :key="action"
    :variant="action === actions[0] ? 'default' : 'outline'"
    :class="action === 'cancel' || action === 'return' ? 'text-red-600' : ''"
    @click="emit('action', action)"
  >
    {{ $t(labelKey(action)) }}
  </Button>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { AdminOrder } from "@/types/shopOrderAdmin";
import type { OrderAction } from "@/utils/shop/orderAdmin";

const props = defineProps<{ order: AdminOrder; actions: OrderAction[] }>();
const emit = defineEmits<{ action: [action: OrderAction] }>();

/** A pickup order's "pack" is "ready to collect". */
const labelKey = (action: OrderAction) =>
  action === "pack" && props.order.deliveryMethod === "pickup" ? "shop.admin.actions.ready" : `shop.admin.actions.${action}`;
</script>
