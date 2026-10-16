<template>
  <AppDialog
    :open="open"
    :title="$t('medical.ward.orderTitle', { name: row?.petName ?? '' })"
    :ok-text="$t('petCare.common.save')"
    :ok-disabled="!valid"
    :busy="saving.isPending.value"
    form-id="ward-order-form"
    size="lg"
    @update:open="emit('update:open', $event)"
  >
    <form id="ward-order-form" class="space-y-4" @submit.prevent="submit">
      <div class="flex gap-1 rounded-lg border bg-muted/40 p-1">
        <button
          v-for="kind in KINDS"
          :key="kind"
          type="button"
          class="flex-1 rounded-md px-3 py-1.5 text-sm font-semibold transition-colors"
          :class="draft.kind === kind ? 'bg-white text-primary shadow-sm' : 'text-muted-foreground'"
          @click="draft.kind = kind"
        >
          {{ $t(`medical.ward.orderKind.${kind}`) }}
        </button>
      </div>

      <div v-if="row?.allergies" class="rounded-lg border border-red-300 bg-red-50 px-3 py-2 text-sm font-semibold text-red-700">
        {{ $t("medical.flags.allergy") }}: {{ row.allergies }}
      </div>

      <div v-if="draft.kind === 'product'" class="space-y-1.5">
        <Label>{{ $t("medical.items.product") }}</Label>
        <p v-if="draft.productId" class="flex items-center justify-between rounded-lg border bg-primary/5 px-3 py-2 text-sm font-semibold">
          {{ draft.name }}
          <button type="button" class="text-xs font-normal text-primary underline" @click="draft.productId = ''">{{ $t("medical.items.change") }}</button>
        </p>
        <ProductPicker v-else allow-untracked @pick="pickProduct" />
      </div>
      <div v-else-if="draft.kind === 'service'" class="space-y-1.5">
        <Label>{{ $t("medical.items.service") }}</Label>
        <Select v-model="draft.serviceId">
          <SelectTrigger :aria-label="$t('medical.items.service')"><SelectValue :placeholder="$t('medical.items.servicePlaceholder')" /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="service in services" :key="service.id" :value="service.id">{{ service.name }}</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div v-else class="space-y-1.5">
        <Label for="ward-care-name">{{ $t("medical.ward.careName") }}</Label>
        <Input id="ward-care-name" v-model="draft.name" :placeholder="$t('medical.ward.carePlaceholder')" />
      </div>

      <div class="grid gap-3 sm:grid-cols-3">
        <div v-if="draft.kind !== 'care'" class="space-y-1.5">
          <Label for="ward-qty">{{ $t("medical.ward.qtyPerDose") }}</Label>
          <Input id="ward-qty" v-model.number="draft.qtyPerDose" type="number" min="0.01" step="any" />
        </div>
        <div class="space-y-1.5" :class="draft.kind === 'care' ? 'sm:col-span-2' : 'sm:col-span-1'">
          <Label for="ward-dose">{{ $t("medical.ward.dose") }}</Label>
          <Input id="ward-dose" v-model="draft.dose" :placeholder="$t('medical.ward.dosePlaceholder')" />
        </div>
        <div class="space-y-1.5">
          <Label for="ward-days">{{ $t("medical.ward.days") }}</Label>
          <Input id="ward-days" v-model.number="draft.days" type="number" min="1" max="30" step="1" />
        </div>
      </div>

      <div class="space-y-1.5">
        <Label>{{ $t("medical.ward.hours") }}</Label>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="hour in HOUR_PRESETS"
            :key="hour"
            type="button"
            class="rounded-full border px-3 py-1 text-sm font-semibold transition-colors"
            :class="draft.times.includes(hour) ? 'border-primary bg-primary text-primary-foreground' : 'bg-white text-muted-foreground hover:bg-muted'"
            @click="toggleHour(hour)"
          >
            {{ hour }}
          </button>
        </div>
      </div>

      <div class="space-y-1.5">
        <Label for="ward-note">{{ $t("medical.ward.note") }}</Label>
        <Input id="ward-note" v-model="draft.note" />
      </div>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useSaveOrder } from "@/queries/inpatient";
import { useAllPetServices } from "@/queries/petServices";
import type { SellableProduct } from "@bongcun/supabase/products";
import type { OrderKind, WardRow } from "@bongcun/core/medical";
import ProductPicker from "@/views/admin/inventory/documents/ProductPicker.vue";
import { emptyOrderDraft, HOUR_PRESETS, isOrderDraftComplete, toOrderInput, type OrderDraft } from "./orderDraft";

const KINDS: OrderKind[] = ["product", "service", "care"];

const props = defineProps<{ open: boolean; row: WardRow | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const saving = useSaveOrder();
const servicesQuery = useAllPetServices("medical");
const services = computed(() => servicesQuery.data.value ?? []);
const serviceNames = computed(() => new Map(services.value.map((service) => [service.id, service.name])));

const draft = ref<OrderDraft>(emptyOrderDraft());
watch(() => props.open, (isOpen) => isOpen && (draft.value = emptyOrderDraft()));

const valid = computed(() => isOrderDraftComplete(draft.value, serviceNames.value));

const pickProduct = (product: SellableProduct) => {
  draft.value.productId = product.id;
  draft.value.name = product.name;
};

const toggleHour = (hour: string) => {
  const times = draft.value.times;
  draft.value.times = times.includes(hour) ? times.filter((time) => time !== hour) : [...times, hour].sort();
};

const submit = async () => {
  if (!props.row || !valid.value) return;
  try {
    await saving.mutateAsync(toOrderInput(props.row.stayPetId, draft.value));
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
