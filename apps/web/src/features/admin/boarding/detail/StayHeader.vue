<template>
  <section class="flex flex-wrap items-start justify-between gap-4 rounded-xl border bg-white p-4">
    <div class="space-y-1">
      <div class="flex flex-wrap items-center gap-2">
        <h2 class="text-lg font-bold">{{ stay.code }}</h2>
        <span class="rounded-full px-2 py-0.5 text-xs font-semibold" :class="STAY_TONE[stay.status]">
          {{ $t(`boarding.status.${stay.status}`) }}
        </span>
        <span v-if="stay.kind === 'inpatient'" class="rounded-full bg-violet-100 px-2 py-0.5 text-xs font-semibold text-violet-800">
          {{ $t("boarding.board.inpatient") }}
        </span>
      </div>
      <p class="text-sm">
        <span class="font-medium">{{ stay.customerName }}</span>
        <span class="text-muted-foreground"> · {{ stay.customerPhone }}</span>
      </p>
      <p class="text-sm text-muted-foreground">
        {{ $t("boarding.detail.in") }}: {{ dateTime(stay.checkedInAt ?? stay.plannedInAt) }}
        · {{ $t("boarding.detail.out") }}: {{ dateTime(stay.checkedOutAt ?? stay.plannedOutAt) }}
      </p>
      <p v-if="stay.emergencyPhone" class="text-sm text-muted-foreground">{{ $t("boarding.dialog.emergencyPhone") }}: {{ stay.emergencyPhone }}</p>
      <p v-if="stay.note" class="text-sm italic text-muted-foreground">{{ stay.note }}</p>
    </div>

    <div v-if="stay.kind !== 'inpatient'" class="flex flex-wrap items-center gap-2">
      <template v-if="stay.status === 'booked'">
        <Button v-if="canCreate" @click="emit('check-in')">{{ $t("boarding.detail.checkIn") }}</Button>
        <Button v-if="canUpdate" variant="outline" @click="emit('edit')">{{ $t("petCare.common.edit") }}</Button>
        <Button v-if="canUpdate" variant="ghost" @click="emit('no-show')">{{ $t("boarding.stays.noShow") }}</Button>
      </template>
      <template v-else-if="stay.status === 'checked_in' && canUpdate">
        <Button variant="outline" @click="emit('extend')">{{ $t("boarding.detail.extend") }}</Button>
        <Button @click="emit('check-out')">{{ $t("boarding.detail.checkOut") }}</Button>
      </template>
      <Button v-else-if="stay.status === 'checked_out'" as-child>
        <router-link :to="{ name: 'pos' }">{{ $t("boarding.detail.payAtPos") }}</router-link>
      </Button>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { BoardingStay } from "@bongcun/core/boarding";
import { dateTime, STAY_TONE } from "../format";

defineProps<{ stay: BoardingStay; canCreate: boolean; canUpdate: boolean }>();
const emit = defineEmits<{ edit: []; "check-in": []; extend: []; "check-out": []; "no-show": [] }>();
</script>
