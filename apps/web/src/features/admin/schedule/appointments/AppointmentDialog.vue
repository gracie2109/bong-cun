<template>
  <AppDialog
    :open="open"
    :title="appointment ? $t('spa.dialog.editTitle', { code: appointment.code }) : $t('spa.dialog.newTitle')"
    :description="$t('spa.dialog.subtitle')"
    :ok-text="appointment ? $t('petCare.common.save') : $t('spa.dialog.book')"
    :ok-disabled="!valid"
    :busy="saving"
    form-id="appointment-form"
    size="lg"
    persistent
    @update:open="emit('update:open', $event)"
  >
    <form id="appointment-form" class="space-y-5" @submit.prevent="submit">
      <section class="space-y-2">
        <Label>{{ $t("spa.dialog.customer") }}</Label>
        <div v-if="appointment" class="rounded-lg border bg-primary/5 px-3 py-2 text-sm">
          <p class="font-semibold">{{ appointment.customerName }}</p>
          <p class="text-xs text-muted-foreground">{{ appointment.customerPhone }}</p>
        </div>
        <CustomerPanel v-else v-model="buyer" :allow-new="false" />
        <p v-if="needsPets" class="rounded-lg border border-dashed px-3 py-2 text-xs text-muted-foreground">
          {{ $t("spa.dialog.noPets") }}
          <router-link :to="{ name: 'pets' }" class="font-semibold text-primary underline">{{ $t("spa.dialog.openPets") }}</router-link>
        </p>
      </section>

      <template v-if="customerId && !needsPets">
        <section class="space-y-2">
          <Label for="appointment-date">{{ $t("spa.dialog.date") }}</Label>
          <Input id="appointment-date" v-model="date" type="date" class="w-48" :min="todayKey()" />
          <p v-if="dayHours?.isClosed" class="text-xs font-semibold text-red-600">{{ $t("spa.errors.closed") }}</p>
          <p v-else-if="slots.length" class="text-xs text-muted-foreground">
            {{ $t("spa.dialog.openHours", { open: dayHours?.openTime ?? DEFAULT_OPEN, close: dayHours?.closeTime ?? DEFAULT_CLOSE }) }}
          </p>
        </section>

        <section class="space-y-3">
          <TicketFields
            v-for="(ticket, index) in tickets"
            :key="ticket.key"
            v-model="tickets[index]"
            :index="index"
            :removable="tickets.length > 1"
            :pets="pets"
            :services="services"
            :combos="combos"
            :staff="staff"
            :resources="resources"
            :slots="slots"
            @remove="tickets.splice(index, 1)"
          />
          <Button type="button" variant="outline" size="sm" @click="addTicket">
            <Plus class="mr-1 size-4" />
            {{ $t("spa.dialog.addTicket") }}
          </Button>
        </section>

        <section class="space-y-2">
          <Label for="appointment-note">{{ $t("spa.dialog.note") }}</Label>
          <Textarea id="appointment-note" v-model="note" rows="2" :placeholder="$t('spa.dialog.notePlaceholder')" />
        </section>
      </template>
    </form>

    <template v-if="appointment && canCancel" #footer="{ cancel, busy }">
      <Button type="button" variant="outline" class="mr-auto text-red-600" :disabled="busy" @click="confirmCancel = true">
        {{ $t("spa.dialog.cancelAppointment") }}
      </Button>
      <Button type="button" variant="outline" :disabled="busy" @click="cancel">{{ $t("petCare.common.cancel") }}</Button>
      <Button type="submit" form="appointment-form" data-dialog-ok :disabled="!valid || busy">
        <Loader2 v-if="busy" class="mr-2 size-4 animate-spin" />
        {{ $t("petCare.common.save") }}
      </Button>
    </template>
  </AppDialog>

  <ConfirmDialog
    :open="confirmCancel"
    :title="$t('spa.dialog.cancelTitle', { code: appointment?.code ?? '' })"
    :desc="$t('spa.dialog.cancelDesc')"
    :ok-btn="$t('spa.dialog.cancelAppointment')"
    :cancel-btn="$t('spa.dialog.keep')"
    danger
    @open-change="confirmCancel = false"
    @handle-ok="cancelAppointment"
  />
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Loader2, Plus } from "lucide-vue-next";
import AppDialog from "@/components/common/AppDialog.vue";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { useAllPetServices } from "@/queries/petServices";
import { useCustomerPets, useSellableCombos } from "@/queries/pos";
import { useBranchStaff, useCancelAppointment, useSaveAppointment, useSpaResources, useWeekHours } from "@/queries/spa";
import type { Appointment } from "@bongcun/supabase/spa";
import { useAuthStore } from "@/stores";
import CustomerPanel, { type Buyer } from "@/features/admin/pos/components/CustomerPanel.vue";
import { dateKeyOf, isoWeekday, timeOf, timeSlots, todayKey } from "../format";
import TicketFields from "./TicketFields.vue";
import { choiceOf, isComplete, newTicketDraft, NONE, toTicketInput, type TicketDraft } from "./ticketDraft";

/** Where a click on the day board started the booking. */
export type BookingPrefill = { date?: string; time?: string; staffId?: string; resourceId?: string };

const DEFAULT_OPEN = "08:00";
const DEFAULT_CLOSE = "20:00";

const props = defineProps<{
  open: boolean;
  branchId: string;
  /** The appointment being edited; null books a new one. */
  appointment: Appointment | null;
  prefill?: BookingPrefill;
}>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const auth = useAuthStore();
const canCancel = computed(() => auth.can("schedule", "DELETE"));

const buyer = ref<Buyer | null>(null);
const date = ref(todayKey());
const note = ref("");
const tickets = ref<TicketDraft[]>([]);
const confirmCancel = ref(false);

const customerId = computed(() => props.appointment?.customerId ?? buyer.value?.customerId ?? null);

const petsQuery = useCustomerPets(customerId);
const pets = computed(() => petsQuery.data.value ?? []);
const needsPets = computed(() => !!buyer.value && !props.appointment && (!buyer.value.customerId || (!petsQuery.isFetching.value && pets.value.length === 0)));

const servicesQuery = useAllPetServices("spa");
const services = computed(() => (servicesQuery.data.value ?? []).filter((service) => service.isShow));
const combosQuery = useSellableCombos();
const combos = computed(() => combosQuery.data.value ?? []);
const branchRef = computed(() => props.branchId);
const staffQuery = useBranchStaff(branchRef);
const staff = computed(() => (staffQuery.data.value ?? []).filter((member) => member.doesServices));
const resourcesQuery = useSpaResources(branchRef);
const resources = computed(() => (resourcesQuery.data.value ?? []).filter((item) => item.isActive));
const hoursQuery = useWeekHours(branchRef);

const dayHours = computed(() => {
  const day = hoursQuery.data.value?.find((item) => item.weekday === isoWeekday(date.value));
  return day ? { isClosed: day.isClosed, openTime: day.openTime, closeTime: day.closeTime } : null;
});
const slots = computed(() => {
  if (dayHours.value?.isClosed) return [];
  return timeSlots(dayHours.value?.openTime ?? DEFAULT_OPEN, dayHours.value?.closeTime ?? DEFAULT_CLOSE);
});

// A time picked for another day's hours may not be offered on this one.
watch(slots, (list) => {
  for (const ticket of tickets.value) if (ticket.time && !list.includes(ticket.time)) ticket.time = "";
});

const addTicket = () => {
  const last = tickets.value.at(-1);
  tickets.value.push(newTicketDraft({ time: last?.time ?? "", staffId: last?.staffId ?? NONE }));
};

const reset = () => {
  confirmCancel.value = false;
  buyer.value = null;
  const existing = props.appointment;
  if (existing) {
    date.value = dateKeyOf(existing.startAt);
    note.value = existing.note ?? "";
    tickets.value = existing.tickets
      .filter((ticket) => ticket.status !== "cancelled")
      .map((ticket) =>
        newTicketDraft({
          petId: ticket.petId ?? "",
          choice: choiceOf(ticket.type, ticket.itemId),
          time: timeOf(ticket.startAt),
          staffId: ticket.staffId ?? NONE,
          resourceId: ticket.resourceId ?? NONE,
        })
      );
    return;
  }
  const hint = props.prefill;
  date.value = hint?.date ?? todayKey();
  note.value = "";
  tickets.value = [
    newTicketDraft({
      time: hint?.time ?? "",
      staffId: hint?.staffId ?? NONE,
      resourceId: hint?.resourceId ?? NONE,
    }),
  ];
};

watch(
  () => props.open,
  (open) => {
    if (open) reset();
  },
  { immediate: true }
);

const valid = computed(() => !!customerId.value && !needsPets.value && tickets.value.length > 0 && tickets.value.every(isComplete));

const saveMutation = useSaveAppointment();
const cancelMutation = useCancelAppointment();
const saving = computed(() => saveMutation.isPending.value || cancelMutation.isPending.value);

const submit = async () => {
  if (!valid.value || !customerId.value) return;
  const inputs = tickets.value.map((ticket) => toTicketInput(ticket, date.value));
  if (inputs.some((input) => !input)) return;
  try {
    await saveMutation.mutateAsync({
      input: {
        branchId: props.branchId,
        customerId: customerId.value,
        note: note.value.trim(),
        tickets: inputs.filter((input): input is NonNullable<typeof input> => !!input),
      },
      id: props.appointment?.id,
    });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};

const cancelAppointment = async () => {
  if (!props.appointment) return;
  try {
    await cancelMutation.mutateAsync({ id: props.appointment.id });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
