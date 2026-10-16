<template>
  <div class="space-y-3">
    <p v-if="entries.length === 0" class="rounded-lg border border-dashed p-6 text-center text-sm text-muted-foreground">
      {{ $t("medical.book.empty") }}
    </p>
    <article v-for="entry in entries" :key="entry.vaccineTypeId" class="space-y-2 rounded-lg border p-3">
      <header class="flex flex-wrap items-center justify-between gap-2">
        <h4 class="font-semibold">{{ entry.name }}</h4>
        <span class="rounded-full px-2 py-0.5 text-[10px] font-semibold" :class="BOOK_STATE_TONE[entry.state]">
          {{ $t(`medical.book.state.${entry.state}`) }}<template v-if="entry.nextDueOn"> · {{ entry.nextDueOn }}</template>
        </span>
      </header>
      <ul class="divide-y text-sm">
        <li v-for="dose in entry.doses" :key="dose.id" class="flex flex-wrap items-center justify-between gap-2 py-1.5" :class="dose.voidedAt && 'text-muted-foreground line-through'">
          <span>
            <span class="font-medium">{{ $t("medical.book.dose", { n: dose.doseNo }) }}</span>
            · {{ dose.givenOn }}
            <template v-if="dose.lotNo"> · {{ $t("medical.book.lot") }} {{ dose.lotNo }}</template>
            <template v-if="dose.isExternal"> · {{ dose.externalPlace || $t("medical.book.external") }}</template>
            <template v-else-if="dose.branchName"> · {{ dose.branchName }}</template>
            <template v-if="dose.vetName"> · {{ dose.vetName }}</template>
          </span>
          <Button v-if="!dose.voidedAt && canVoid(dose)" size="sm" variant="ghost" class="text-red-600" @click="emit('void', dose)">
            {{ $t("medical.book.void") }}
          </Button>
        </li>
      </ul>
    </article>
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { VaccineBookEntry, VaccineDose } from "@/types/vaccination";
import { BOOK_STATE_TONE } from "../format";

defineProps<{ entries: VaccineBookEntry[]; canVoid: (dose: VaccineDose) => boolean }>();
const emit = defineEmits<{ void: [dose: VaccineDose] }>();
</script>
