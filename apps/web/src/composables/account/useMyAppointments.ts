import { computed, ref, watch } from "vue";
import { useCancelMyAppointment, useMyAppointments as useMyAppointmentsQuery } from "@/queries/accountAppointments";
import { useMyProfile } from "@/queries/account";
import type { AppointmentScope, MyAppointment } from "@bongcun/core/account";

const PAGE_SIZE = 10;

/** The "Lịch hẹn" page: upcoming / past tabs, paging and cancelling with a confirmation. */
export const useMyAppointments = () => {
  const profile = useMyProfile();
  const hasCustomer = computed(() => Boolean(profile.data.value?.customerId));

  const scope = ref<AppointmentScope>("upcoming");
  const page = ref(1);
  watch(scope, () => (page.value = 1));

  const query = useMyAppointmentsQuery(scope, page, PAGE_SIZE, hasCustomer);
  const rows = computed(() => query.data.value?.rows ?? []);
  const total = computed(() => query.data.value?.total ?? 0);
  const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));

  const mutation = useCancelMyAppointment();
  const toCancel = ref<MyAppointment | null>(null);
  const confirmCancel = async () => {
    const appointment = toCancel.value;
    toCancel.value = null;
    if (!appointment) return;
    try {
      await mutation.mutateAsync(appointment.id);
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return {
    scope,
    page,
    pageSize: PAGE_SIZE,
    rows,
    total,
    pageCount,
    loading: computed(() => profile.isLoading.value || (hasCustomer.value && query.isLoading.value)),
    fetching: query.isFetching,
    failed: computed(() => profile.isError.value || query.isError.value),
    retry: () => {
      void profile.refetch();
      void query.refetch();
    },
    toCancel,
    confirmCancel,
    cancelling: mutation.isPending,
  };
};
