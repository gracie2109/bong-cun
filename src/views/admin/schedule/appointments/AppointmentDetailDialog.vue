<template>
  <AppDialog
    :open="open"
    :title="$t('spa.detail.title', { code: current?.code ?? '' })"
    :description="$t('spa.detail.subtitle')"
    size="xl"
    hide-footer
    @update:open="emit('update:open', $event)"
  >
    <div v-if="current" class="space-y-5">
      <section class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="font-semibold">{{ current.customerName }}</p>
          <p class="text-xs text-muted-foreground">{{ current.customerPhone }}</p>
          <p class="mt-1 text-xs text-muted-foreground">
            {{ dateTime(current.startAt) }} → {{ timeOf(current.endAt) }}
            <template v-if="current.checkedInAt">· {{ $t("spa.detail.checkedInAt", { time: dateTime(current.checkedInAt) }) }}</template>
          </p>
        </div>
        <span class="rounded-full px-3 py-1 text-xs font-semibold" :class="APPOINTMENT_TONE[current.status]">
          {{ $t(`spa.status.${current.status}`) }}
        </span>
      </section>

      <p v-if="current.note" class="rounded-lg border bg-muted/40 px-3 py-2 text-sm">{{ current.note }}</p>

      <section v-if="canCheckIn" class="space-y-2 rounded-xl border border-primary/30 bg-primary/5 p-3">
        <p class="text-sm font-semibold">{{ $t("spa.detail.checkIn") }}</p>
        <p class="text-xs text-muted-foreground">{{ $t("spa.detail.checkInHint") }}</p>
        <PetHealthFlagsBanner :pets="pets" />
        <div class="grid gap-2 sm:grid-cols-2">
          <label v-for="pet in pets" :key="pet.id" class="flex items-center justify-between gap-3 text-sm">
            <span class="font-medium">{{ pet.name }}</span>
            <span class="flex items-center gap-1">
              <Input v-model="weights[pet.id]" type="number" inputmode="decimal" min="0" step="0.1" class="h-9 w-28 bg-white text-right" :aria-label="$t('spa.detail.weight', { name: pet.name })" />
              <span class="text-xs text-muted-foreground">kg</span>
            </span>
          </label>
        </div>
        <Button :disabled="busy || !weightsValid" @click="checkIn">
          <LogIn class="mr-2 size-4" />
          {{ $t("spa.detail.checkInAction") }}
        </Button>
      </section>

      <section class="space-y-2">
        <p class="text-sm font-semibold">{{ $t("spa.detail.tickets") }}</p>
        <ul class="divide-y rounded-xl border">
          <TicketRow
            v-for="ticket in current.tickets"
            :key="ticket.id"
            :ticket="ticket"
            :can-serve="canServe"
            :busy="busy"
            @status="setStatus(ticket.id, $event)"
          />
        </ul>
        <p class="text-right text-sm">
          {{ $t("spa.detail.total") }}: <span class="font-semibold">{{ money(total) }}</span>
        </p>
        <p v-if="payable" class="rounded-lg border border-dashed px-3 py-2 text-xs text-muted-foreground">
          {{ $t("spa.detail.payHint") }}
          <router-link :to="{ name: 'pos' }" class="font-semibold text-primary underline">{{ $t("spa.detail.openPos") }}</router-link>
        </p>
      </section>

      <div class="flex flex-wrap items-center justify-between gap-2 border-t pt-4">
        <div class="flex flex-wrap gap-2">
          <Button v-if="canNoShow" variant="outline" class="text-slate-600" :disabled="busy" @click="confirm = 'noShow'">
            {{ $t("spa.detail.noShow") }}
          </Button>
          <Button v-if="canCancel" variant="outline" class="text-red-600" :disabled="busy" @click="confirm = 'cancel'">
            {{ $t("spa.dialog.cancelAppointment") }}
          </Button>
        </div>
        <div class="flex gap-2">
          <Button v-if="canEdit" variant="outline" :disabled="busy" @click="emit('edit', current)">{{ $t("petCare.common.edit") }}</Button>
          <Button variant="outline" @click="emit('update:open', false)">{{ $t("spa.detail.close") }}</Button>
        </div>
      </div>
    </div>
    <p v-else class="py-8 text-center text-sm text-muted-foreground">{{ $t("spa.detail.loading") }}</p>
  </AppDialog>

  <ConfirmDialog
    :open="confirm !== null"
    :title="confirmTitle"
    :desc="confirm === 'noShow' ? $t('spa.detail.noShowDesc') : $t('spa.dialog.cancelDesc')"
    :ok-btn="confirm === 'noShow' ? $t('spa.detail.noShow') : $t('spa.dialog.cancelAppointment')"
    :cancel-btn="$t('spa.dialog.keep')"
    danger
    @open-change="confirm = null"
    @handle-ok="runConfirmed"
  />
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import { LogIn } from "lucide-vue-next";
import AppDialog from "@/components/common/AppDialog.vue";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { Appointment } from "@/repositories/spa";
import { money } from "@/views/admin/pos/format";
import PetHealthFlagsBanner from "@/views/admin/medical/flags/PetHealthFlagsBanner.vue";
import { APPOINTMENT_TONE, dateTime, timeOf } from "../format";
import TicketRow from "./TicketRow.vue";
import { useAppointmentDetail } from "./useAppointmentDetail";

const props = defineProps<{
  open: boolean;
  /** The appointment shown; the dialog keeps it fresh by id while it is open. */
  appointment: Appointment | null;
}>();
const emit = defineEmits<{ "update:open": [value: boolean]; edit: [appointment: Appointment] }>();

const {
  current, total, pets, weights, weightsValid,
  canCheckIn, canServe, canEdit, canNoShow, canCancel, payable,
  busy, checkIn, setStatus, confirm, confirmTitle, runConfirmed,
} = useAppointmentDetail(toRef(props, "open"), toRef(props, "appointment"));
</script>
