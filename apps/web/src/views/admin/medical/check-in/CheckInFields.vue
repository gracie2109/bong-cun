<template>
  <section class="space-y-4">
    <div class="space-y-1.5">
      <Label>{{ $t("medical.checkIn.pet") }}</Label>
      <p v-if="petLocked" class="rounded-lg border bg-muted/40 px-3 py-2 text-sm font-semibold">{{ petName }}</p>
      <Select v-else v-model="draft.petId">
        <SelectTrigger :aria-label="$t('medical.checkIn.pet')"><SelectValue :placeholder="$t('medical.checkIn.petPlaceholder')" /></SelectTrigger>
        <SelectContent>
          <SelectItem v-for="pet in pets" :key="pet.id" :value="pet.id">
            {{ pet.name }} · {{ pet.speciesName }}<template v-if="pet.weightKg"> · {{ pet.weightKg }} kg</template>
          </SelectItem>
        </SelectContent>
      </Select>
    </div>

    <div v-if="draft.mode === 'book' && !petLocked" class="grid gap-3 sm:grid-cols-2">
      <div class="space-y-1.5">
        <Label for="medical-book-date">{{ $t("medical.checkIn.date") }}</Label>
        <Input id="medical-book-date" v-model="draft.date" type="date" required />
      </div>
      <div class="space-y-1.5">
        <Label for="medical-book-time">{{ $t("medical.checkIn.time") }}</Label>
        <Input id="medical-book-time" v-model="draft.time" type="time" required />
      </div>
    </div>

    <div class="space-y-1.5">
      <Label for="medical-reason">{{ $t("medical.checkIn.reason") }}</Label>
      <Textarea id="medical-reason" v-model="draft.reason" rows="2" :placeholder="$t('medical.checkIn.reasonPlaceholder')" />
    </div>

    <div class="grid gap-3 sm:grid-cols-2">
      <div class="space-y-1.5">
        <Label>{{ $t("medical.checkIn.vet") }}</Label>
        <Select v-model="draft.vetId">
          <SelectTrigger :aria-label="$t('medical.checkIn.vet')"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem :value="NO_VET">{{ $t("medical.checkIn.noVet") }}</SelectItem>
            <SelectItem v-for="vet in vets" :key="vet.id" :value="vet.id">{{ vet.name }}</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <label v-if="draft.mode === 'now' || petLocked" class="flex items-center gap-2 self-end rounded-lg border px-3 py-2 text-sm font-medium">
        <input v-model="draft.urgent" type="checkbox" class="size-4 accent-red-600" />
        {{ $t("medical.checkIn.urgent") }}
      </label>
    </div>

    <div v-if="draft.mode === 'now' || petLocked" class="grid gap-3 sm:grid-cols-2">
      <div class="space-y-1.5">
        <Label for="medical-weight">{{ $t("medical.vitals.weight") }}</Label>
        <Input id="medical-weight" v-model="draft.weight" inputmode="decimal" placeholder="kg" />
      </div>
      <div class="space-y-1.5">
        <Label for="medical-temp">{{ $t("medical.vitals.temperature") }}</Label>
        <Input id="medical-temp" v-model="draft.temperature" inputmode="decimal" placeholder="°C" />
      </div>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import type { CustomerPet } from "@/repositories/pos";
import type { Vet } from "@bongcun/core/medical";
import { NO_VET, type CheckInDraft } from "./checkInDraft";

defineProps<{ pets: CustomerPet[]; vets: Vet[]; petLocked: boolean; petName?: string }>();
const draft = defineModel<CheckInDraft>("draft", { required: true });
</script>
