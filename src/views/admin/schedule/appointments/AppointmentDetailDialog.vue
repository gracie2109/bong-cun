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
          <li v-for="ticket in current.tickets" :key="ticket.id" class="flex flex-wrap items-center justify-between gap-3 px-3 py-2.5 text-sm">
            <div :class="ticket.status === 'cancelled' && 'text-muted-foreground line-through'">
              <p>
                <span class="font-medium">{{ ticket.petName ?? "—" }}</span>
                · {{ ticket.name }}
              </p>
              <p class="text-xs text-muted-foreground">
                {{ timeOf(ticket.startAt) }} – {{ timeOf(ticket.endAt) }}
                <template v-if="ticket.staffName">· {{ ticket.staffName }}</template>
                <template v-if="ticket.resourceName">· {{ ticket.resourceName }}</template>
                <template v-if="ticket.weightKg">· {{ ticket.weightKg }} kg</template>
              </p>
            </div>
            <div class="flex items-center gap-3">
              <div class="text-right">
                <p class="font-semibold">{{ money(ticket.unitPrice ?? ticket.estPrice) }}</p>
                <p class="text-[10px] uppercase text-muted-foreground">
                  {{ ticket.unitPrice !== null ? $t("spa.detail.finalPrice") : $t("spa.detail.estimate") }}
                </p>
              </div>
              <span class="rounded-full px-2 py-0.5 text-[10px] font-semibold" :class="TICKET_BADGE[ticket.status]">
                {{ $t(`spa.ticketStatus.${ticket.status}`) }}
              </span>
              <template v-if="canServe && ticket.status !== 'cancelled'">
                <Button v-if="ticket.status === 'waiting'" size="sm" :disabled="busy" @click="setStatus(ticket.id, 'in_progress')">
                  <Play class="mr-1 size-3.5" />
                  {{ $t("spa.detail.start") }}
                </Button>
                <template v-else-if="ticket.status === 'in_progress'">
                  <Button size="sm" :disabled="busy" @click="setStatus(ticket.id, 'done')">
                    <Check class="mr-1 size-3.5" />
                    {{ $t("spa.detail.finish") }}
                  </Button>
                  <Button size="sm" variant="ghost" :disabled="busy" :aria-label="$t('spa.detail.undo')" @click="setStatus(ticket.id, 'waiting')">
                    <Undo2 class="size-3.5" />
                  </Button>
                </template>
                <Button v-else size="sm" variant="ghost" :disabled="busy" :aria-label="$t('spa.detail.undo')" @click="setStatus(ticket.id, 'in_progress')">
                  <Undo2 class="size-3.5" />
                </Button>
              </template>
            </div>
          </li>
        </ul>
        <p class="text-right text-sm">
          {{ $t("spa.detail.total") }}: <span class="font-semibold">{{ money(total) }}</span>
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
import { computed, reactive, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { Check, LogIn, Play, Undo2 } from "lucide-vue-next";
import AppDialog from "@/components/common/AppDialog.vue";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  useAppointment,
  useCancelAppointment,
  useCheckInAppointment,
  useMarkNoShow,
  useSetTicketStatus,
} from "@/queries/spa";
import { isCancellable, isEditable, isServing, type Appointment, type TicketStatus } from "@/repositories/spa";
import { useAuthStore } from "@/stores";
import { money } from "@/views/admin/pos/format";
import { APPOINTMENT_TONE, dateTime, timeOf } from "../format";

const TICKET_BADGE: Record<TicketStatus, string> = {
  waiting: "bg-sky-50 text-sky-700",
  in_progress: "bg-violet-50 text-violet-700",
  done: "bg-primary/10 text-primary",
  cancelled: "bg-red-50 text-red-600",
};

const props = defineProps<{
  open: boolean;
  /** The appointment shown; the dialog keeps it fresh by id while it is open. */
  appointment: Appointment | null;
}>();
const emit = defineEmits<{ "update:open": [value: boolean]; edit: [appointment: Appointment] }>();

const { t } = useI18n();
const auth = useAuthStore();

const appointmentId = computed(() => (props.open ? props.appointment?.id : undefined));
const freshQuery = useAppointment(appointmentId);
const current = computed(() => freshQuery.data.value ?? props.appointment);

const liveTickets = computed(() => (current.value?.tickets ?? []).filter((ticket) => ticket.status !== "cancelled"));
const total = computed(() => liveTickets.value.reduce((sum, ticket) => sum + (ticket.unitPrice ?? ticket.estPrice ?? 0), 0));

// One weight per pet, however many tickets it has.
const pets = computed(() => {
  const seen = new Map<string, { id: string; name: string; weightKg: number | null }>();
  for (const ticket of liveTickets.value) {
    if (ticket.petId && !seen.has(ticket.petId)) {
      seen.set(ticket.petId, { id: ticket.petId, name: ticket.petName ?? "", weightKg: ticket.weightKg });
    }
  }
  return [...seen.values()];
});
const weights = reactive<Record<string, string>>({});
watch(
  () => [props.open, props.appointment?.id] as const,
  ([open]) => {
    if (!open) return;
    for (const key of Object.keys(weights)) delete weights[key];
    for (const pet of pets.value) weights[pet.id] = pet.weightKg ? String(pet.weightKg) : "";
  },
  { immediate: true }
);
const weightsValid = computed(() => Object.values(weights).every((value) => value === "" || Number(value) > 0));

const status = computed(() => current.value?.status);
const canCheckIn = computed(() => status.value === "booked" && auth.can("schedule", "CREATE"));
const canServe = computed(() => !!status.value && isServing(status.value) && auth.can("schedule", "UPDATE"));
const canEdit = computed(() => !!status.value && isEditable(status.value) && auth.can("schedule", "UPDATE"));
const canNoShow = computed(
  () => status.value === "booked" && auth.can("schedule", "UPDATE") && new Date(current.value?.startAt ?? 0) <= new Date()
);
const canCancel = computed(
  () =>
    !!status.value &&
    isCancellable(status.value) &&
    auth.can("schedule", "DELETE") &&
    liveTickets.value.every((ticket) => ticket.status === "waiting")
);

const checkInMutation = useCheckInAppointment();
const statusMutation = useSetTicketStatus();
const noShowMutation = useMarkNoShow();
const cancelMutation = useCancelAppointment();
const busy = computed(
  () =>
    checkInMutation.isPending.value ||
    statusMutation.isPending.value ||
    noShowMutation.isPending.value ||
    cancelMutation.isPending.value
);

// The mutations already show the failure toast, so a failed call only has to stay quiet here.
const checkIn = async () => {
  if (!current.value || !weightsValid.value) return;
  const given = pets.value
    .filter((pet) => weights[pet.id] !== "")
    .map((pet) => ({ petId: pet.id, weightKg: Number(weights[pet.id]) }));
  await checkInMutation.mutateAsync({ id: current.value.id, weights: given }).catch(() => undefined);
};

const setStatus = async (ticketId: string, next: TicketStatus) => {
  await statusMutation.mutateAsync({ ticketId, status: next }).catch(() => undefined);
};

const confirm = ref<"noShow" | "cancel" | null>(null);
const confirmTitle = computed(() =>
  t(confirm.value === "noShow" ? "spa.detail.noShowTitle" : "spa.dialog.cancelTitle", { code: current.value?.code ?? "" })
);

const runConfirmed = async () => {
  const id = current.value?.id;
  const action = confirm.value;
  confirm.value = null;
  if (!id || !action) return;
  try {
    if (action === "noShow") await noShowMutation.mutateAsync(id);
    else await cancelMutation.mutateAsync({ id });
  } catch {
    return;
  }
};
</script>
