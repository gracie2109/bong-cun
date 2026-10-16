<template>
  <DialogHeader>
    <DialogTitle class="flex items-center gap-2">
      <CircleCheck class="size-5 text-primary" />
      {{ $t("pos.payment.done") }}
    </DialogTitle>
    <DialogDescription>{{ result.code }}</DialogDescription>
  </DialogHeader>
  <p v-if="result.replayed" class="rounded-lg bg-amber-50 p-3 text-sm text-amber-800">{{ $t("pos.payment.replayed") }}</p>
  <div class="space-y-2 rounded-xl bg-muted/50 p-4">
    <div class="flex justify-between text-sm">
      <span class="text-muted-foreground">{{ $t("pos.total") }}</span>
      <span class="font-semibold">{{ money(result.total) }}</span>
    </div>
    <div class="flex justify-between">
      <span class="text-muted-foreground">{{ $t("pos.change") }}</span>
      <span class="text-2xl font-bold text-primary">{{ money(result.changeAmount) }}</span>
    </div>
  </div>
  <DialogFooter class="gap-2">
    <Button variant="outline" :disabled="printing" @click="emit('print')">
      <Printer class="mr-2 size-4" />
      {{ $t("pos.payment.print") }}
    </Button>
    <Button @click="emit('newSale')">{{ $t("pos.payment.newSale") }}</Button>
  </DialogFooter>
</template>

<script lang="ts" setup>
import { CircleCheck, Printer } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import type { SaleResult } from "@/repositories/pos";
import { money } from "../format";

defineProps<{ result: SaleResult; printing: boolean }>();

const emit = defineEmits<{ print: []; newSale: [] }>();
</script>
