<template>
  <div class="space-y-3 rounded-lg border border-amber-200 p-3">
    <p class="text-sm font-semibold">{{ $t("pos.returns.formTitle") }}</p>
    <div v-for="line in lines" :key="line.id" class="flex items-center justify-between gap-3 text-sm">
      <span class="min-w-0">
        <span class="block truncate font-medium">{{ line.name }}</span>
        <span class="text-xs text-muted-foreground">{{ $t("pos.returns.canReturn", { n: line.qty - returnedQty(line.id) }) }}</span>
      </span>
      <Input v-model="quantities[line.id]" inputmode="decimal" class="h-8 w-20 text-right" placeholder="0" />
    </div>
    <div class="flex flex-wrap gap-2">
      <Button
        v-for="method in REFUND_METHODS"
        :key="method"
        type="button"
        size="sm"
        :variant="refundMethod === method ? 'default' : 'outline'"
        @click="refundMethod = method"
      >
        {{ $t(`pos.method.${method}`) }}
      </Button>
    </div>
    <div class="space-y-2">
      <Label for="return-reason">{{ $t("pos.returns.reason") }}</Label>
      <Textarea id="return-reason" v-model="reason" rows="2" class="resize-none" />
    </div>
    <p v-if="invalid" class="text-sm text-red-600">{{ $t("pos.returns.invalidQty") }}</p>
    <div class="flex items-center justify-between gap-2">
      <span class="text-sm">{{ $t("pos.returns.refund") }} <b class="text-red-600">{{ money(refundPreview) }}</b></span>
      <div class="flex gap-2">
        <Button variant="outline" size="sm" @click="emit('cancel')">{{ $t("petCare.common.cancel") }}</Button>
        <Button size="sm" :disabled="!canSubmit" @click="emit('submit')">
          {{ $t("pos.returns.confirm") }}
        </Button>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { REFUND_METHODS, type InvoiceLine, type RefundMethod } from "@/repositories/pos";
import { money } from "../format";

defineProps<{
  /** Lines with something left to return. */
  lines: InvoiceLine[];
  returnedQty: (lineId: string) => number;
  invalid: boolean;
  refundPreview: number;
  canSubmit: boolean;
}>();

const emit = defineEmits<{ cancel: []; submit: [] }>();

/** Quantity typed per line id. */
const quantities = defineModel<Record<string, string>>("quantities", { required: true });
const reason = defineModel<string>("reason", { required: true });
const refundMethod = defineModel<RefundMethod>("refundMethod", { required: true });
</script>
