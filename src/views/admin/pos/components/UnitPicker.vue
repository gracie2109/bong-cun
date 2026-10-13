<template>
  <AppDialog
    :open="!!item"
    :title="item?.name ?? ''"
    :description="$t('pos.units.subtitle')"
    :ok-text="$t('pos.variant.add')"
    size="md"
    @update:open="(value) => !value && emit('close')"
    @ok="add"
  >
    <UnitOptions
      v-if="item"
      v-model="picked"
      :base-unit="item.baseUnit ?? item.unit ?? ''"
      :base-price="item.basePrice ?? item.price ?? 0"
      :units="item.units ?? []"
      :stock="stock"
    />
  </AppDialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import type { CatalogItem } from "../catalog";
import { itemInUnit } from "../unitPricing";
import UnitOptions from "./UnitOptions.vue";

const props = defineProps<{ item: CatalogItem | null; stock: number | undefined }>();
const emit = defineEmits<{ close: []; pick: [item: CatalogItem] }>();

const picked = ref<string | null>(null);
watch(() => props.item, () => (picked.value = null));

const add = () => {
  if (!props.item) return;
  const unit = props.item.units?.find((candidate) => candidate.id === picked.value) ?? null;
  emit("pick", itemInUnit(props.item, unit));
  emit("close");
};
</script>
