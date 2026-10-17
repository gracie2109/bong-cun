<template>
  <AppDialog
    :open="open"
    :title="$t('medical.items.addService')"
    :description="$t('medical.items.serviceHint')"
    :ok-text="$t('medical.items.addLine')"
    :ok-disabled="!serviceId || qty <= 0"
    :busy="saving"
    form-id="medical-service-form"
    size="sm"
    @update:open="emit('update:open', $event)"
  >
    <form id="medical-service-form" class="space-y-4" @submit.prevent="submit">
      <div class="space-y-1.5">
        <Label>{{ $t("medical.items.service") }}</Label>
        <Select v-model="serviceId">
          <SelectTrigger :aria-label="$t('medical.items.service')"><SelectValue :placeholder="$t('medical.items.servicePlaceholder')" /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="service in services" :key="service.id" :value="service.id">{{ service.name }}</SelectItem>
          </SelectContent>
        </Select>
        <p v-if="services.length === 0" class="text-xs text-muted-foreground">{{ $t("medical.items.noServices") }}</p>
      </div>
      <div class="space-y-1.5">
        <Label for="medical-service-qty">{{ $t("medical.items.qty") }}</Label>
        <Input id="medical-service-qty" v-model.number="qty" type="number" min="1" step="1" />
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
import { useAllPetServices } from "@/features/admin/pets/queries/petServices";
import type { ItemInput } from "@bongcun/core/medical";

const props = defineProps<{ open: boolean; saving: boolean; add: (input: ItemInput) => Promise<boolean> }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const servicesQuery = useAllPetServices("medical");
const services = computed(() => servicesQuery.data.value ?? []);

const serviceId = ref("");
const qty = ref(1);
watch(() => props.open, (isOpen) => {
  if (!isOpen) return;
  serviceId.value = "";
  qty.value = 1;
});

const submit = async () => {
  if (!serviceId.value || qty.value <= 0) return;
  const ok = await props.add({
    kind: "service", serviceId: serviceId.value, qty: qty.value,
    takeHome: false, dose: "", frequency: "", days: null, route: "", instructions: "",
  });
  if (ok) emit("update:open", false);
};
</script>
