// State and actions of the appointment detail: what the signed-in user may do, the check-in
// weights, and the calls that move the appointment along.
import { computed, reactive, ref, watch, type Ref } from "vue";
import { useI18n } from "vue-i18n";
import {
  useAppointment,
  useCancelAppointment,
  useCheckInAppointment,
  useMarkNoShow,
  useSetTicketStatus,
} from "@/queries/spa";
import { isCancellable, isEditable, isServing, type Appointment, type TicketStatus } from "@/repositories/spa";
import { useAuthStore } from "@/stores";

export type ConfirmKind = "noShow" | "cancel";

export const useAppointmentDetail = (open: Ref<boolean>, appointment: Ref<Appointment | null>) => {
  const { t } = useI18n();
  const auth = useAuthStore();

  const appointmentId = computed(() => (open.value ? appointment.value?.id : undefined));
  const freshQuery = useAppointment(appointmentId);
  const current = computed(() => freshQuery.data.value ?? appointment.value);

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
    () => [open.value, appointment.value?.id] as const,
    ([isOpen]) => {
      if (!isOpen) return;
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

  // Finished tickets still waiting for an invoice can be paid at the POS.
  const payable = computed(
    () => !!status.value && isServing(status.value) && liveTickets.value.some((ticket) => ticket.status === "done" && !ticket.billed)
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

  const confirm = ref<ConfirmKind | null>(null);
  const confirmTitle = computed(() =>
    t(confirm.value === "noShow" ? "spa.detail.noShowTitle" : "spa.dialog.cancelTitle", { code: current.value?.code ?? "" })
  );

  const runConfirmed = async () => {
    const id = current.value?.id;
    const action = confirm.value;
    confirm.value = null;
    if (!id || !action) return;
    const run = action === "noShow" ? noShowMutation.mutateAsync(id) : cancelMutation.mutateAsync({ id });
    await run.catch(() => undefined);
  };

  return {
    current, liveTickets, total, pets, weights, weightsValid,
    canCheckIn, canServe, canEdit, canNoShow, canCancel, payable,
    busy, checkIn, setStatus, confirm, confirmTitle, runConfirmed,
  };
};
