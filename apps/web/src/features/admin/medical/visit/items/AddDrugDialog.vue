<template>
  <AppDialog
    :open="open"
    :title="$t('medical.items.addDrug')"
    :description="$t('medical.items.drugHint')"
    :ok-text="$t('medical.items.addLine')"
    :ok-disabled="!valid"
    :busy="saving"
    form-id="medical-drug-form"
    size="lg"
    @update:open="emit('update:open', $event)"
  >
    <form id="medical-drug-form" class="space-y-4" @submit.prevent="submit">
      <div class="flex gap-1 rounded-lg border bg-muted/40 p-1">
        <button
          v-for="source in SOURCES"
          :key="source"
          type="button"
          class="flex-1 rounded-md px-3 py-1.5 text-sm font-semibold transition-colors"
          :class="draft.source === source ? 'bg-white text-primary shadow-sm' : 'text-muted-foreground'"
          @click="draft.source = source"
        >
          {{ $t(`medical.items.source.${source}`) }}
        </button>
      </div>

      <div v-if="petAllergies" class="rounded-lg border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
        <p class="font-semibold">{{ $t("medical.flags.allergy") }}: {{ petAllergies }}</p>
        <label v-if="draft.source === 'stock'" class="mt-1 flex items-center gap-2 font-medium">
          <input v-model="draft.allergyChecked" type="checkbox" class="size-4 accent-red-600" />
          {{ $t("medical.items.allergyChecked") }}
        </label>
      </div>

      <div v-if="draft.source === 'stock'" class="space-y-1.5">
        <Label>{{ $t("medical.items.product") }}</Label>
        <p v-if="draft.productId" class="flex items-center justify-between rounded-lg border bg-primary/5 px-3 py-2 text-sm font-semibold">
          {{ draft.productName }}
          <button type="button" class="text-xs font-normal text-primary underline" @click="draft.productId = ''">{{ $t("medical.items.change") }}</button>
        </p>
        <ProductPicker v-else allow-untracked @pick="pickProduct" />
      </div>
      <div v-else class="space-y-1.5">
        <Label for="drug-external-name">{{ $t("medical.items.externalName") }}</Label>
        <Input id="drug-external-name" v-model="draft.externalName" />
        <p class="text-xs text-muted-foreground">{{ $t("medical.items.externalHint") }}</p>
      </div>

      <div class="space-y-1.5 sm:w-40">
        <Label for="drug-qty">{{ $t("medical.items.qty") }}</Label>
        <Input id="drug-qty" v-model="draft.qty" inputmode="decimal" />
      </div>

      <DrugFields v-model:draft="draft" />
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { SellableProduct } from "@bongcun/supabase/products";
import type { ItemInput } from "@bongcun/core/medical";
import ProductPicker from "@/features/admin/inventory/documents/ProductPicker.vue";
import DrugFields from "./DrugFields.vue";
import { emptyDrugDraft, isDrugDraftComplete, toDrugInput, type DrugDraft } from "./itemDraft";

const SOURCES = ["stock", "external"] as const;

const props = defineProps<{
  open: boolean;
  saving: boolean;
  petAllergies: string | null;
  add: (input: ItemInput) => Promise<boolean>;
}>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const draft = ref<DrugDraft>(emptyDrugDraft());
watch(() => props.open, (isOpen) => isOpen && (draft.value = emptyDrugDraft()));

const valid = computed(() => isDrugDraftComplete(draft.value, !!props.petAllergies));

const pickProduct = (product: SellableProduct) => {
  draft.value.productId = product.id;
  draft.value.productName = product.name;
};

const submit = async () => {
  if (!valid.value) return;
  if (await props.add(toDrugInput(draft.value))) emit("update:open", false);
};
</script>
