<template>
  <DropdownMenu>
    <DropdownMenuTrigger as-child>
      <Button variant="ghost" size="icon" class="size-7" :aria-label="$t('medical.ward.orderActions')">
        <EllipsisVertical class="size-4" />
      </Button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="end">
      <DropdownMenuItem @click="emit('edit')">{{ $t("petCare.common.edit") }}</DropdownMenuItem>
      <DropdownMenuItem v-if="order.kind !== 'care'" @click="emit('replace')">{{ $t("medical.ward.replace") }}</DropdownMenuItem>
      <DropdownMenuItem class="text-red-600" @click="emit('stop')">{{ $t("medical.ward.stop") }}</DropdownMenuItem>
    </DropdownMenuContent>
  </DropdownMenu>
</template>

<script lang="ts" setup>
import { EllipsisVertical } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import type { WardOrder } from "@bongcun/core/medical";

defineProps<{ order: WardOrder }>();
const emit = defineEmits<{ edit: []; replace: []; stop: [] }>();
</script>
