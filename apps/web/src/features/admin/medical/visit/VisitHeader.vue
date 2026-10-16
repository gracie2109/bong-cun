<template>
  <section class="flex flex-wrap items-start justify-between gap-4 rounded-xl border bg-white p-4">
    <div class="space-y-1">
      <div class="flex flex-wrap items-center gap-2">
        <h2 class="text-lg font-bold">{{ visit.code }}</h2>
        <span class="rounded-full px-2 py-0.5 text-xs font-semibold" :class="VISIT_TONE[visit.status]">
          {{ $t(`medical.status.${visit.status}`) }}
        </span>
        <span v-if="visit.priority === 'urgent'" class="rounded-full bg-red-600 px-2 py-0.5 text-xs font-semibold text-white">
          {{ $t("medical.priority.urgent") }}
        </span>
      </div>
      <p class="text-sm">
        <span class="font-medium">{{ visit.petName }}</span>
        <span class="text-muted-foreground"> · {{ visit.customerName }} · {{ visit.customerPhone }}</span>
      </p>
      <p class="text-sm text-muted-foreground">
        {{ visit.branchName }}<template v-if="visit.queueNo"> · #{{ visit.queueNo }}</template>
        <template v-if="visit.vetName"> · {{ visit.vetName }}</template>
        · {{ dateTime(visit.checkedInAt ?? visit.scheduledAt ?? visit.createdAt) }}
      </p>
      <p v-if="visit.reason" class="text-sm">{{ visit.reason }}</p>
      <p v-if="visit.followUpCode" class="text-xs text-muted-foreground">{{ $t("medical.detail.recheckOf", { code: visit.followUpCode }) }}</p>
      <p v-if="visit.recheckVisit" class="text-xs text-muted-foreground">
        {{ $t("medical.detail.recheckBooked", { code: visit.recheckVisit.code }) }}
        <router-link :to="{ name: 'medicalVisitDetail', params: { visitId: visit.recheckVisit.id } }" class="font-semibold text-primary underline">
          {{ $t("medical.visits.open") }}
        </router-link>
      </p>
      <p v-if="visit.cancelReason" class="text-sm italic text-muted-foreground">{{ visit.cancelReason }}</p>
    </div>

    <div class="flex flex-wrap items-center gap-2">
      <Button v-if="canUpdate && visit.status === 'waiting'" @click="emit('start')">{{ $t("medical.queue.takeCase") }}</Button>
      <Button v-if="visit.status === 'done'" as-child>
        <router-link :to="{ name: 'pos' }">{{ $t("medical.detail.payAtPos") }}</router-link>
      </Button>
      <Button v-if="canCancel && CANCELLABLE.includes(visit.status) && !visit.signedAt" variant="outline" class="text-red-600" @click="emit('cancel')">
        {{ $t("medical.cancel.action") }}
      </Button>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { MedicalVisitDetail, VisitStatus } from "@bongcun/core/medical";
import { dateTime, VISIT_TONE } from "../format";

const CANCELLABLE: VisitStatus[] = ["scheduled", "waiting", "in_progress"];

defineProps<{ visit: MedicalVisitDetail; canUpdate: boolean; canCancel: boolean }>();
const emit = defineEmits<{ start: []; cancel: [] }>();
</script>
