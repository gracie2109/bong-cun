<template>
  <Popover v-model:open="open">
    <PopoverTrigger as-child>
      <button type="button" class="rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-semibold text-amber-800 hover:bg-amber-200">
        {{ $t("medical.ward.edited", { count: order.edited }) }}
      </button>
    </PopoverTrigger>
    <PopoverContent align="start" class="w-80 space-y-2 text-xs">
      <p class="text-sm font-semibold">{{ $t("medical.ward.history") }}</p>
      <p v-if="history.isPending.value" class="text-muted-foreground">…</p>
      <ul v-else class="max-h-72 space-y-2 overflow-y-auto">
        <li v-for="change in history.data.value ?? []" :key="change.id" class="space-y-0.5 border-b pb-2 last:border-b-0">
          <p class="font-semibold">
            {{ $t(`medical.ward.action.${change.action}`) }}
            <span class="font-normal text-muted-foreground">· {{ change.changedByName ?? "—" }} · {{ dateTime(change.changedAt) }}</span>
          </p>
          <p v-for="part in changedFields(change.before, change.after)" :key="part.field">
            {{ $t(`medical.ward.field.${part.field}`) }}: <span class="text-muted-foreground">{{ part.before }}</span> → {{ part.after }}
          </p>
          <p v-if="change.reason" class="italic text-muted-foreground">{{ change.reason }}</p>
        </li>
      </ul>
    </PopoverContent>
  </Popover>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { useOrderHistory } from "@/queries/inpatient";
import type { WardOrder } from "@bongcun/core/medical";
import { dateTime } from "../format";
import { changedFields } from "./orderHistoryText";

const props = defineProps<{ order: WardOrder }>();
const open = ref(false);
const history = useOrderHistory(computed(() => props.order.id), open);
</script>
