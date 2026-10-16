<template>
  <tr class="border-t" :class="category.isActive ? '' : 'opacity-60'">
    <td class="px-4 py-3">
      <div class="flex items-center gap-3" :class="category.parentId ? 'pl-6' : ''">
        <ProductThumb :src="category.imageUrl" class="size-9 shrink-0" />
        <div class="min-w-0">
          <p class="flex items-center gap-2 font-semibold">
            <span v-if="category.parentId" class="text-muted-foreground">›</span>
            {{ category.name }}
            <span v-if="!category.isActive" class="rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold text-muted-foreground">
              {{ $t("productCatalog.inactive") }}
            </span>
          </p>
          <p v-if="category.parentName && showParent" class="text-xs text-muted-foreground">{{ category.parentName }}</p>
        </div>
      </div>
    </td>
    <td class="px-4 py-3 font-mono text-xs text-muted-foreground">{{ category.slug }}</td>
    <td class="px-4 py-3 text-right tabular-nums">{{ category.productCount }}</td>
    <td class="px-4 py-3">
      <div v-if="canUpdate && canMove" class="flex gap-1">
        <Button variant="ghost" size="icon" class="size-8" :aria-label="$t('productCatalog.moveUp')" @click="emit('move', category, 'up')">
          <ArrowUp class="size-4" />
        </Button>
        <Button variant="ghost" size="icon" class="size-8" :aria-label="$t('productCatalog.moveDown')" @click="emit('move', category, 'down')">
          <ArrowDown class="size-4" />
        </Button>
      </div>
    </td>
    <td class="px-4 py-3 text-right">
      <DropdownMenu v-if="canUpdate || canDelete">
        <DropdownMenuTrigger as-child>
          <Button variant="ghost" size="icon" class="size-8"><EllipsisVertical class="size-4" /></Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem v-if="canUpdate" @click="emit('edit', category)">{{ $t("petCare.common.edit") }}</DropdownMenuItem>
          <DropdownMenuItem v-if="canUpdate" @click="emit('setActive', category, !category.isActive)">
            {{ category.isActive ? $t("productCatalog.deactivate") : $t("productCatalog.activate") }}
          </DropdownMenuItem>
          <DropdownMenuItem v-if="canDelete && deletable" class="text-red-600" @click="emit('remove', category)">
            {{ $t("common.delete") }}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { ArrowDown, ArrowUp, EllipsisVertical } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type { ProductCategory } from "@/repositories/productCategories";
import ProductThumb from "../ProductThumb.vue";

const props = defineProps<{
  category: ProductCategory;
  canUpdate: boolean;
  canDelete: boolean;
  /** Reordering makes sense only in the full list, not in search results. */
  canMove: boolean;
  /** Show the parent's name under a sub-category (search results lose the grouping). */
  showParent: boolean;
}>();

const emit = defineEmits<{
  edit: [category: ProductCategory];
  setActive: [category: ProductCategory, isActive: boolean];
  move: [category: ProductCategory, direction: "up" | "down"];
  remove: [category: ProductCategory];
}>();

/** Only a category with no products and no sub-categories can be deleted. */
const deletable = computed(() => props.category.productCount === 0 && props.category.childCount === 0);
</script>
