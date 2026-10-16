<template>
  <tr class="border-t align-top">
    <td class="px-3 py-3">
      <p class="font-medium">{{ item.name }}</p>
      <p v-if="directions" class="text-xs text-muted-foreground">{{ directions }}</p>
      <p class="mt-0.5 flex flex-wrap items-center gap-1">
        <span class="rounded-full px-2 py-0.5 text-[10px] font-semibold" :class="KIND_TONE[item.kind]">{{ $t(`medical.items.kind.${item.kind}`) }}</span>
        <span v-if="item.takeHome && item.kind !== 'external'" class="rounded-full bg-violet-100 px-2 py-0.5 text-[10px] font-semibold text-violet-800">
          {{ $t("medical.items.takeHome") }}
        </span>
        <span v-if="item.invoiceLineId" class="rounded-full bg-slate-200 px-2 py-0.5 text-[10px] font-semibold text-slate-700">{{ $t("medical.items.billed") }}</span>
      </p>
    </td>
    <td class="whitespace-nowrap px-3 py-3 text-right">
      <Input
        v-if="editable"
        :model-value="item.qty"
        type="number"
        min="0.01"
        step="any"
        class="ml-auto h-8 w-20 text-right"
        @change="onQty"
      />
      <template v-else>{{ item.qty }}</template>
      <span v-if="item.unitName" class="ml-1 text-xs text-muted-foreground">{{ item.unitName }}</span>
    </td>
    <td class="whitespace-nowrap px-3 py-3 text-right">{{ item.kind === "external" ? "-" : money(item.unitPrice) }}</td>
    <td class="whitespace-nowrap px-3 py-3 text-right font-medium">{{ item.kind === "external" ? "-" : money(item.amount) }}</td>
    <td class="px-3 py-3 text-xs text-muted-foreground">{{ item.createdByName }}<br />{{ dateTime(item.createdAt) }}</td>
    <td class="px-3 py-3 text-right">
      <Button v-if="editable" size="icon" variant="ghost" class="size-8 text-red-600" :aria-label="$t('medical.items.remove')" @click="emit('remove')">
        <Trash2 class="size-4" />
      </Button>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Trash2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { VisitItem } from "@bongcun/core/medical";
import { dateTime, money } from "../../format";

const props = defineProps<{ item: VisitItem; canEdit: boolean }>();
const emit = defineEmits<{ remove: []; "change-qty": [qty: number] }>();

const KIND_TONE: Record<VisitItem["kind"], string> = {
  service: "bg-sky-100 text-sky-800",
  product: "bg-emerald-100 text-emerald-800",
  external: "bg-amber-100 text-amber-800",
};

// A line that is on an invoice is closed.
const editable = computed(() => props.canEdit && !props.item.invoiceLineId);

const directions = computed(() =>
  [props.item.dose, props.item.frequency, props.item.days ? `${props.item.days} ngày` : null, props.item.route, props.item.instructions]
    .filter(Boolean)
    .join(" · ")
);

const onQty = (event: Event) => {
  const value = Number((event.target as HTMLInputElement).value);
  if (value > 0 && value !== props.item.qty) emit("change-qty", value);
};
</script>
