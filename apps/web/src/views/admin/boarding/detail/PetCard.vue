<template>
  <article class="space-y-2 rounded-xl border bg-white p-4" :class="pet.status === 'cancelled' && 'opacity-60'">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <h3 class="font-semibold">
        {{ pet.petName }}
        <span v-if="pet.hasNotes" class="ml-1 text-amber-600" :title="$t('boarding.board.hasNotes')">⚠ {{ $t("boarding.detail.hasNotes") }}</span>
      </h3>
      <div class="flex items-center gap-2">
        <span class="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-semibold text-primary">
          {{ pet.kennelCode }} · {{ pet.kennelTypeName }}
        </span>
        <Button v-if="canMove" variant="outline" size="sm" class="h-7 text-xs" @click="emit('move')">
          <ArrowRightLeft class="mr-1 size-3.5" />{{ $t("boarding.move.button") }}
        </Button>
      </div>
    </div>
    <dl class="grid gap-x-4 gap-y-1 text-sm sm:grid-cols-2">
      <div>
        <dt class="text-xs text-muted-foreground">{{ $t("boarding.detail.nights") }}</dt>
        <dd>{{ pet.nightsFrom }} → {{ pet.nightsTo }} · {{ pet.chargedNights }} {{ $t("boarding.detail.nightUnit") }}</dd>
      </div>
      <div>
        <dt class="text-xs text-muted-foreground">{{ $t("boarding.detail.price") }}</dt>
        <dd>{{ money(pet.nightPrice ?? pet.estNightPrice) }}<span v-if="pet.nightPrice === null" class="text-muted-foreground"> ({{ $t("boarding.detail.estimated") }})</span></dd>
      </div>
      <div v-if="pet.weightKg !== null">
        <dt class="text-xs text-muted-foreground">{{ $t("boarding.detail.weight") }}</dt>
        <dd>{{ pet.weightKg }} kg</dd>
      </div>
      <div v-if="checkedIn">
        <dt class="text-xs text-muted-foreground">{{ $t("boarding.detail.vaccine") }}</dt>
        <dd :class="!pet.vaccineChecked && 'font-semibold text-amber-700'">
          {{ pet.vaccineChecked ? $t("boarding.detail.vaccineSeen") : $t("boarding.detail.vaccineNotSeen") }}
          <span v-if="pet.vaccineNote" class="font-normal text-muted-foreground">· {{ pet.vaccineNote }}</span>
        </dd>
      </div>
      <div v-if="pet.feeding">
        <dt class="text-xs text-muted-foreground">{{ $t("boarding.dialog.feeding") }}</dt>
        <dd>{{ pet.feeding }}</dd>
      </div>
      <div v-if="pet.medication">
        <dt class="text-xs text-muted-foreground">{{ $t("boarding.dialog.medication") }}</dt>
        <dd>{{ pet.medication }}</dd>
      </div>
      <div v-if="pet.belongings">
        <dt class="text-xs text-muted-foreground">{{ $t("boarding.dialog.belongings") }}</dt>
        <dd>{{ pet.belongings }}<span v-if="pet.belongingsReturned" class="text-emerald-700"> · {{ $t("boarding.detail.returned") }}</span></dd>
      </div>
    </dl>
  </article>
</template>

<script lang="ts" setup>
import { ArrowRightLeft } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import type { StayPet } from "@bongcun/core/boarding";
import { money } from "../format";

defineProps<{ pet: StayPet; checkedIn: boolean; canMove?: boolean }>();
const emit = defineEmits<{ move: [] }>();
</script>
