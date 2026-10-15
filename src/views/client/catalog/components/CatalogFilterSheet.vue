<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="left" class="flex w-[88%] max-w-sm flex-col gap-0 p-0">
      <SheetHeader class="border-b px-5 py-4 text-left">
        <SheetTitle class="text-lg font-bold">{{ $t("client.catalog.filters") }}</SheetTitle>
      </SheetHeader>
      <div class="flex-1 overflow-y-auto px-5 py-5"><slot /></div>
      <div class="border-t p-4">
        <Button class="h-12 w-full rounded-full text-base" @click="emit('update:open', false)">
          {{ $t("client.catalog.showResults", { count: total }) }}
        </Button>
      </div>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet";

defineProps<{ open: boolean; count: number; total: number }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();
</script>
