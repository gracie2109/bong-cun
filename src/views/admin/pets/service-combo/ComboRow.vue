<template>
  <tr class="border-t" :class="combo.isActive ? '' : 'opacity-60'">
    <td class="px-4 py-3">
      <p class="flex flex-wrap items-center gap-2 font-semibold">
        {{ combo.name }}
        <span
          v-if="combo.markAsId && combo.markAsId !== DEFAULT_MARK"
          class="rounded-full bg-primary/10 px-2 py-0.5 text-[10px] font-semibold text-primary"
        >
          {{ $t(`petCare.combos.marks.${combo.markAsId}`) }}
        </span>
      </p>
      <p v-if="combo.desc" class="line-clamp-1 text-xs text-muted-foreground">{{ combo.desc }}</p>
    </td>
    <td class="px-4 py-3">
      <div class="flex flex-wrap gap-1">
        <span
          v-for="item in combo.species"
          :key="item.id"
          class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary"
        >
          {{ item.name }}
        </span>
      </div>
    </td>
    <td class="px-4 py-3 text-xs text-muted-foreground">
      {{ combo.serviceProfiles.map((service) => service.name).join(", ") }}
    </td>
    <td class="whitespace-nowrap px-4 py-3">
      <p class="font-semibold">{{ formatPrice(combo.price ?? 0) }}</p>
      <p v-if="combo.origin_price" class="text-xs text-muted-foreground line-through">
        {{ formatPrice(combo.origin_price) }}
      </p>
    </td>
    <td class="px-4 py-3">
      <span class="rounded-full px-2 py-0.5 text-[11px] font-semibold" :class="COMBO_STATUS_CLASS[status]">
        {{ $t(`petCare.combos.status.${status}`) }}
      </span>
    </td>
    <td class="px-4 py-3 text-right">
      <DropdownMenu v-if="canUpdate">
        <DropdownMenuTrigger as-child>
          <Button variant="ghost" size="icon" class="size-8"><EllipsisVertical class="size-4" /></Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem @click="emit('edit', combo)">{{ $t("petCare.common.edit") }}</DropdownMenuItem>
          <DropdownMenuItem v-if="combo.isActive" @click="emit('archive', combo)">
            {{ $t("petCare.common.archive") }}
          </DropdownMenuItem>
          <DropdownMenuItem v-else @click="emit('restore', combo)">
            {{ $t("petCare.common.restore") }}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { EllipsisVertical } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { formatPrice } from "@/lib/utils";
import type { PetCombo } from "@/repositories/petCombos";
import { COMBO_STATUS_CLASS, comboStatus, DEFAULT_MARK } from "./comboStatus";

const props = defineProps<{ combo: PetCombo; canUpdate: boolean }>();

const emit = defineEmits<{
  edit: [combo: PetCombo];
  archive: [combo: PetCombo];
  restore: [combo: PetCombo];
}>();

const status = computed(() => comboStatus(props.combo));
</script>
