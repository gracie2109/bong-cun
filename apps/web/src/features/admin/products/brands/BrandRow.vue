<template>
  <tr class="border-t" :class="brand.isActive ? '' : 'opacity-60'">
    <td class="px-4 py-3">
      <div class="flex items-center gap-3">
        <ProductThumb :src="brand.imageUrl" class="size-9 shrink-0" />
        <p class="flex items-center gap-2 font-semibold">
          {{ brand.name }}
          <span v-if="!brand.isActive" class="rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold text-muted-foreground">
            {{ $t("productCatalog.inactive") }}
          </span>
        </p>
      </div>
    </td>
    <td class="px-4 py-3 font-mono text-xs text-muted-foreground">{{ brand.slug }}</td>
    <td class="px-4 py-3 text-right tabular-nums">{{ brand.productCount }}</td>
    <td class="px-4 py-3 text-right">
      <DropdownMenu v-if="canUpdate || canDelete">
        <DropdownMenuTrigger as-child>
          <Button variant="ghost" size="icon" class="size-8"><EllipsisVertical class="size-4" /></Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem v-if="canUpdate" @click="emit('edit', brand)">{{ $t("petCare.common.edit") }}</DropdownMenuItem>
          <DropdownMenuItem v-if="canUpdate" @click="emit('setActive', brand, !brand.isActive)">
            {{ brand.isActive ? $t("productCatalog.deactivate") : $t("productCatalog.activate") }}
          </DropdownMenuItem>
          <DropdownMenuItem v-if="canDelete && brand.productCount === 0" class="text-red-600" @click="emit('remove', brand)">
            {{ $t("common.delete") }}
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
import type { ProductBrand } from "@bongcun/supabase/products";
import ProductThumb from "../ProductThumb.vue";

defineProps<{ brand: ProductBrand; canUpdate: boolean; canDelete: boolean }>();

const emit = defineEmits<{
  edit: [brand: ProductBrand];
  setActive: [brand: ProductBrand, isActive: boolean];
  remove: [brand: ProductBrand];
}>();
</script>
