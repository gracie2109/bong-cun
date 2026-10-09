<template>
  <AppDialog
    :open="!!groupId"
    :title="group?.name ?? title"
    :description="$t('pos.variant.subtitle')"
    :ok-text="$t('pos.variant.add')"
    :ok-disabled="!selected || stockOf(selected) === 0"
    size="lg"
    @update:open="(value) => !value && emit('close')"
    @ok="add"
  >

    <div v-if="groupQuery.isPending.value" class="space-y-2">
      <Skeleton class="h-6 w-1/3" />
      <Skeleton class="h-9 w-full" />
    </div>
    <template v-else-if="group">
      <div class="flex gap-4">
        <ProductThumb :src="choice.variant.value?.imageUrl || group.imageUrl" class="size-20 shrink-0" />
        <VariantOptions
          class="min-w-0 flex-1"
          :attributes="choice.attributes.value"
          :picks="choice.picks.value"
          :is-available="choice.isAvailable"
          @pick="choice.pick"
        />
      </div>

      <div class="flex items-center justify-between rounded-lg bg-muted/50 px-3 py-2 text-sm">
        <span v-if="selected" class="min-w-0 truncate text-muted-foreground">
          {{ [selected.sku, selected.unit].filter(Boolean).join(" · ") }}
          <span v-if="stockOf(selected) !== undefined" :class="stockOf(selected) === 0 ? 'text-red-600' : ''">
            ·
            {{ stockOf(selected) === 0 ? $t("pos.catalog.outOfStock") : $t("pos.catalog.inStock", { n: qty(stockOf(selected)) }) }}
          </span>
        </span>
        <span v-else class="text-muted-foreground">{{ $t("pos.variant.pickAll") }}</span>
        <span v-if="selected" class="whitespace-nowrap font-bold text-primary">{{ money(selected.price) }}</span>
      </div>
    </template>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, toRef, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Skeleton } from "@/components/ui/skeleton";
import VariantOptions from "@/components/VariantOptions.vue";
import { useVariantChoice } from "@/composables/useVariantChoice";
import { useSellableStock } from "@/queries/inventory";
import { useSellableGroup } from "@/queries/products";
import type { ProductVariant } from "@/repositories/products";
import { qty } from "@/views/admin/inventory/format";
import ProductThumb from "@/views/admin/products/ProductThumb.vue";
import { money } from "../format";

const props = defineProps<{ groupId: string | undefined; title: string; branchId: string | undefined }>();
const emit = defineEmits<{ close: []; pick: [variant: ProductVariant] }>();

const groupQuery = useSellableGroup(toRef(props, "groupId"));
const group = computed(() => groupQuery.data.value ?? null);

const variantIds = computed(() => group.value?.variants.map((variant) => variant.id) ?? []);
const stockQuery = useSellableStock(toRef(props, "branchId"), variantIds);
const stockOf = (variant: ProductVariant): number | undefined => stockQuery.data.value?.[variant.id];

const choice = useVariantChoice(group, (variant) => stockOf(variant) !== 0);
const selected = computed(() => choice.variant.value);

// Stock arrives after the group: start again on a variant that is in stock.
watch(() => stockQuery.data.value, choice.reset);

const add = () => {
  if (!selected.value) return;
  emit("pick", selected.value);
  emit("close");
};
</script>
