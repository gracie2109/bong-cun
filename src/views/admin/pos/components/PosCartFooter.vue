<template>
  <div class="space-y-3 border-t p-3">
    <div class="flex items-center justify-between gap-3 text-sm">
      <span class="text-muted-foreground">{{ $t("pos.subtotal") }}</span>
      <span class="font-semibold">{{ money(subtotal) }}</span>
    </div>
    <div class="flex items-center justify-between gap-3 text-sm">
      <Label for="pos-discount" class="text-muted-foreground">{{ $t("pos.discount") }}</Label>
      <div class="flex items-center gap-2">
        <span v-if="discount > 0 && subtotal > 0" class="text-xs text-muted-foreground">
          {{ Math.round((discount / subtotal) * 1000) / 10 }}%
        </span>
        <Input id="pos-discount" v-model="discountText" class="h-8 w-32 text-right" inputmode="numeric" placeholder="0" />
      </div>
    </div>
    <p v-if="discountProblem" class="text-xs text-red-600">{{ discountProblem }}</p>
    <Input v-model="note" class="h-8 text-sm" :placeholder="$t('pos.cart.note')" />
    <div class="flex items-center justify-between">
      <span class="font-semibold">{{ $t("pos.total") }}</span>
      <span class="text-2xl font-bold text-primary">{{ money(total) }}</span>
    </div>
    <div class="flex gap-2">
      <Button variant="outline" :disabled="!hasLines" @click="emit('clear')">{{ $t("pos.cart.clear") }}</Button>
      <Button class="flex-1" size="lg" :disabled="!canCheckout" @click="emit('checkout')">
        <CreditCard class="mr-2 size-4" />
        {{ $t("pos.cart.checkout") }}
      </Button>
    </div>
    <p v-if="checkoutBlocker" class="text-center text-xs text-muted-foreground">{{ checkoutBlocker }}</p>
  </div>
</template>

<script lang="ts" setup>
import { CreditCard } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { money } from "../format";

defineProps<{
  subtotal: number;
  discount: number;
  total: number;
  discountProblem: string;
  checkoutBlocker: string;
  canCheckout: boolean;
  hasLines: boolean;
}>();

const emit = defineEmits<{ clear: []; checkout: [] }>();

const discountText = defineModel<string>("discountText", { required: true });
const note = defineModel<string>("note", { required: true });
</script>
