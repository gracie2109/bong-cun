<template>
  <div class="space-y-3 rounded-lg border p-3">
    <div class="flex items-center justify-between gap-2">
      <p class="text-sm font-semibold">{{ $t("spa.dialog.ticket", { n: index + 1 }) }}</p>
      <Button v-if="removable" type="button" size="sm" variant="ghost" :aria-label="$t('spa.dialog.removeTicket')" @click="emit('remove')">
        <Trash2 class="size-4" />
      </Button>
    </div>

    <div class="grid gap-3 sm:grid-cols-2">
      <div class="space-y-1.5">
        <Label>{{ $t("spa.dialog.pet") }}</Label>
        <Select :model-value="ticket.petId" @update:model-value="(value) => setPet(String(value))">
          <SelectTrigger><SelectValue :placeholder="$t('spa.dialog.pickPet')" /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="pet in pets" :key="pet.id" :value="pet.id">{{ pet.name }} · {{ pet.speciesName }}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div class="space-y-1.5">
        <Label>{{ $t("spa.dialog.service") }}</Label>
        <Select v-model="ticket.choice" :disabled="!ticket.petId">
          <SelectTrigger><SelectValue :placeholder="$t('spa.dialog.pickService')" /></SelectTrigger>
          <SelectContent>
            <SelectGroup v-if="serviceOptions.length">
              <SelectLabel>{{ $t("spa.dialog.services") }}</SelectLabel>
              <SelectItem v-for="item in serviceOptions" :key="item.value" :value="item.value">{{ item.label }}</SelectItem>
            </SelectGroup>
            <SelectGroup v-if="comboOptions.length">
              <SelectLabel>{{ $t("spa.dialog.combos") }}</SelectLabel>
              <SelectItem v-for="item in comboOptions" :key="item.value" :value="item.value">{{ item.label }}</SelectItem>
            </SelectGroup>
          </SelectContent>
        </Select>
      </div>

      <div class="space-y-1.5">
        <Label>{{ $t("spa.dialog.time") }}</Label>
        <Select v-model="ticket.time" :disabled="!slots.length">
          <SelectTrigger><SelectValue :placeholder="$t('spa.dialog.pickTime')" /></SelectTrigger>
          <SelectContent class="max-h-64">
            <SelectItem v-for="slot in slots" :key="slot" :value="slot">{{ slot }}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div class="space-y-1.5">
        <Label>{{ $t("spa.dialog.staff") }}</Label>
        <Select v-model="ticket.staffId">
          <SelectTrigger><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem :value="NONE">{{ $t("spa.dialog.unassigned") }}</SelectItem>
            <SelectItem v-for="member in staff" :key="member.userId" :value="member.userId">{{ member.name }}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div class="space-y-1.5 sm:col-span-2">
        <Label>{{ $t("spa.dialog.table") }}</Label>
        <Select v-model="ticket.resourceId">
          <SelectTrigger><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem :value="NONE">{{ $t("spa.dialog.noTable") }}</SelectItem>
            <SelectItem v-for="item in resources" :key="item.id" :value="item.id">{{ item.name }}</SelectItem>
          </SelectContent>
        </Select>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Trash2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectGroup, SelectItem, SelectLabel, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { CustomerPet, SellableCombo } from "@/repositories/pos";
import type { PetService } from "@/repositories/petServices";
import type { BranchStaff, SpaResource } from "@/repositories/spa";
import { choiceOf, NONE, type TicketDraft } from "./ticketDraft";

const props = defineProps<{
  index: number;
  removable: boolean;
  pets: CustomerPet[];
  services: PetService[];
  combos: SellableCombo[];
  staff: BranchStaff[];
  resources: SpaResource[];
  slots: string[];
}>();

const ticket = defineModel<TicketDraft>({ required: true });
const emit = defineEmits<{ remove: [] }>();

const species = computed(() => props.pets.find((pet) => pet.id === ticket.value.petId)?.speciesId);

// A service or combo without species applies to every species, as in the price list.
const forSpecies = (speciesIds: string[]) => !species.value || speciesIds.length === 0 || speciesIds.includes(species.value);

const serviceOptions = computed(() =>
  props.services
    .filter((service) => forSpecies(service.speciesIds))
    .map((service) => ({ value: choiceOf("service", service.id), label: service.name }))
);
const comboOptions = computed(() =>
  props.combos
    .filter((combo) => forSpecies(combo.speciesIds))
    .map((combo) => ({ value: choiceOf("combo", combo.id), label: combo.name }))
);

// Changing the pet may leave a service that is not offered for the new species.
const setPet = (petId: string) => {
  ticket.value.petId = petId;
  const offered = [...serviceOptions.value, ...comboOptions.value];
  if (!offered.some((item) => item.value === ticket.value.choice)) ticket.value.choice = "";
};
</script>
