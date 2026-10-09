<template>
  <tr class="border-t" :class="supplier.isActive ? '' : 'opacity-60'">
    <td class="px-4 py-3">
      <p class="flex items-center gap-2 font-semibold">
        {{ supplier.name }}
        <span v-if="!supplier.isActive" class="rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold text-muted-foreground">
          {{ $t("petCare.common.archived") }}
        </span>
      </p>
      <p v-if="supplier.note" class="line-clamp-1 text-xs text-muted-foreground">{{ supplier.note }}</p>
    </td>
    <td class="px-4 py-3">{{ supplier.phone ?? "—" }}</td>
    <td class="px-4 py-3 font-mono text-xs">{{ supplier.taxCode ?? "—" }}</td>
    <td class="max-w-64 px-4 py-3"><span class="line-clamp-1">{{ supplier.address ?? "—" }}</span></td>
    <td class="px-4 py-3 text-right">
      <DropdownMenu v-if="canUpdate">
        <DropdownMenuTrigger as-child>
          <Button variant="ghost" size="icon" class="size-8"><EllipsisVertical class="size-4" /></Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem @click="emit('edit', supplier)">{{ $t("petCare.common.edit") }}</DropdownMenuItem>
          <DropdownMenuItem @click="emit('setActive', supplier, !supplier.isActive)">
            {{ supplier.isActive ? $t("petCare.common.archive") : $t("petCare.common.restore") }}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { EllipsisVertical } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type { Supplier } from "@/repositories/inventory";

defineProps<{ supplier: Supplier; canUpdate: boolean }>();

const emit = defineEmits<{ edit: [supplier: Supplier]; setActive: [supplier: Supplier, isActive: boolean] }>();
</script>
