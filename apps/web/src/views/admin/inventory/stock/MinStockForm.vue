<template>
  <form class="flex flex-wrap items-end gap-3" @submit.prevent="save">
    <div class="space-y-2">
      <Label for="min-qty">{{ $t("inventory.stock.minLabel") }}</Label>
      <Input id="min-qty" v-model="minText" class="w-40" inputmode="decimal" :disabled="!canUpdate" placeholder="0" />
    </div>
    <Button v-if="canUpdate" type="submit" variant="outline" :disabled="!changed || mutation.isPending.value">
      {{ $t("petCare.common.save") }}
    </Button>
    <p class="basis-full text-xs text-muted-foreground">{{ $t("inventory.stock.minHint") }}</p>
  </form>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { usePermission } from "@/composables/usePermission";
import { useSetMinStock } from "@/queries/inventory";
import type { StockRow } from "@/repositories/inventory";
import { parseQty } from "../format";

const props = defineProps<{ row: StockRow; branchId: string | undefined }>();

const { canUpdate } = usePermission("inventory");
const mutation = useSetMinStock();
const minText = ref("");

watch(
  () => [props.row.productId, props.row.minQty] as const,
  () => {
    minText.value = props.row.minQty ? String(props.row.minQty) : "";
  },
  { immediate: true }
);

const minValue = computed(() => {
  const value = parseQty(minText.value);
  return Number.isFinite(value) && value > 0 ? value : null;
});
const changed = computed(() => minValue.value !== (props.row.minQty || null));

const save = async () => {
  if (!props.branchId) return;
  try {
    await mutation.mutateAsync({ branchId: props.branchId, productId: props.row.productId, minQty: minValue.value });
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
