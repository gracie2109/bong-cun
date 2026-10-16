<template>
  <div class="space-y-4">
    <form v-if="canAdd" class="grid gap-3 rounded-xl border bg-white p-4 sm:grid-cols-[1fr_2fr_6rem_auto] sm:items-end" @submit.prevent="submit">
      <div v-if="pets.length > 1" class="space-y-1.5">
        <Label>{{ $t("boarding.dialog.pet") }}</Label>
        <Select v-model="petId">
          <SelectTrigger><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="pet in pets" :key="pet.id" :value="pet.id">{{ pet.petName }}</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div class="space-y-1.5" :class="pets.length <= 1 && 'sm:col-span-2'">
        <Label>{{ $t("boarding.extras.service") }}</Label>
        <Select v-model="serviceId">
          <SelectTrigger><SelectValue :placeholder="$t('boarding.extras.pick')" /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="service in services" :key="service.id" :value="service.id">{{ service.name }}</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div class="space-y-1.5">
        <Label for="extra-qty">{{ $t("boarding.extras.qty") }}</Label>
        <Input id="extra-qty" v-model.number="qty" type="number" min="1" step="1" />
      </div>
      <Button type="submit" :disabled="!serviceId || !petId || qty < 1 || adding.isPending.value">
        <Plus class="mr-1 size-4" />
        {{ $t("boarding.extras.add") }}
      </Button>
    </form>

    <p v-if="extras.length === 0" class="rounded-xl border border-dashed bg-white p-6 text-center text-sm text-muted-foreground">
      {{ $t("boarding.extras.empty") }}
    </p>
    <ul v-else class="divide-y rounded-xl border bg-white">
      <li v-for="extra in extras" :key="extra.id" class="flex items-center justify-between gap-3 px-4 py-3 text-sm">
        <div>
          <p class="font-medium">{{ extra.name }} × {{ extra.qty }}</p>
          <p class="text-xs text-muted-foreground">{{ extra.petName }} · {{ money(extra.unitPrice) }}</p>
        </div>
        <div class="flex items-center gap-2">
          <span class="font-semibold">{{ money(extra.amount) }}</span>
          <Button v-if="canRemove && !extra.invoiceLineId" variant="ghost" size="icon" class="size-8" @click="remove.mutate(extra.id)">
            <Trash2 class="size-4" />
          </Button>
        </div>
      </li>
    </ul>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Plus, Trash2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useAddBoardingExtra, useRemoveBoardingExtra } from "@/queries/boarding";
import { useAllPetServices } from "@/queries/petServices";
import type { StayCharge, StayPet } from "@bongcun/core/boarding";
import { money } from "../format";

const props = defineProps<{ charges: StayCharge[]; pets: StayPet[]; canAdd: boolean; canRemove: boolean }>();

const adding = useAddBoardingExtra();
const remove = useRemoveBoardingExtra();
const servicesQuery = useAllPetServices();
const services = computed(() => servicesQuery.data.value ?? []);
const extras = computed(() => props.charges.filter((charge) => charge.kind === "extra"));

const petId = ref(props.pets[0]?.id ?? "");
const serviceId = ref("");
const qty = ref(1);

const submit = async () => {
  try {
    await adding.mutateAsync({ stayPetId: petId.value, serviceId: serviceId.value, qty: qty.value });
    serviceId.value = "";
    qty.value = 1;
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
