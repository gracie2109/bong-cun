<template>
  <tr
    class="border-t"
    :class="[group.isActive ? '' : 'opacity-60', canUpdate ? 'cursor-pointer hover:bg-muted/40' : '']"
    @click="canUpdate && emit('edit', group.id)"
  >
    <td class="px-4 py-3">
      <div class="flex items-center gap-3">
        <ProductThumb :src="group.imageUrl ?? group.variants.find((item) => item.imageUrl)?.imageUrl" class="size-10 shrink-0" />
        <div class="min-w-0">
          <p class="flex items-center gap-2 font-semibold">
            {{ group.name }}
            <span v-if="!group.isActive" class="rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold text-muted-foreground">
              {{ $t("petCare.common.archived") }}
            </span>
          </p>
          <p v-if="group.desc" class="line-clamp-1 text-xs text-muted-foreground">{{ group.desc }}</p>
        </div>
      </div>
    </td>
    <td class="px-4 py-3">
      <template v-if="group.attributes.length">
        <p class="font-medium">{{ $t("products.variantsCount", { n: group.variants.length }) }}</p>
        <p class="text-xs text-muted-foreground">
          {{ group.attributes.map((item) => `${item.name}: ${item.values.join(", ")}`).join(" · ") }}
        </p>
      </template>
      <span v-else class="text-muted-foreground">—</span>
    </td>
    <td class="px-4 py-3">
      <template v-if="group.variants.length === 1">
        {{ group.variants[0]?.sku ?? "—" }}
        <span v-if="group.variants[0]?.barcode" class="block font-mono text-xs text-muted-foreground">{{ group.variants[0]?.barcode }}</span>
      </template>
      <span v-else class="text-muted-foreground">—</span>
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{{ priceRange }}</td>
    <td class="px-4 py-3 text-right" @click.stop>
      <DropdownMenu v-if="canUpdate">
        <DropdownMenuTrigger as-child>
          <Button variant="ghost" size="icon" class="size-8"><EllipsisVertical class="size-4" /></Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem @click="emit('edit', group.id)">{{ $t("petCare.common.edit") }}</DropdownMenuItem>
          <DropdownMenuItem @click="emit('setActive', group, !group.isActive)">
            {{ group.isActive ? $t("petCare.common.archive") : $t("petCare.common.restore") }}
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
import type { ProductGroup } from "@/repositories/products";
import { money } from "@/views/admin/pos/format";
import ProductThumb from "./ProductThumb.vue";

const props = defineProps<{ group: ProductGroup; canUpdate: boolean }>();

const emit = defineEmits<{ edit: [groupId: string]; setActive: [group: ProductGroup, isActive: boolean] }>();

/** One price, or the lowest and highest when the variants differ. */
const priceRange = computed(() => {
  const { minPrice, maxPrice } = props.group;
  if (minPrice === null || maxPrice === null) return "—";
  if (minPrice === maxPrice) return money(minPrice);
  return `${money(minPrice)} – ${money(maxPrice)}`;
});
</script>
