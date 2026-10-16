import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { sendMessageToast } from "@/lib/utils";
import { toPage, type PageParams } from "@bongcun/supabase/shared";
import {
  cancelAppointment,
  checkInAppointment,
  findAppointment,
  getAppointment,
  getDayBoard,
  getWeekHours,
  listAppointments,
  listBillableTickets,
  listBranchStaff,
  listSpaResources,
  markNoShow,
  saveAppointment,
  saveSpaResource,
  saveWeekHours,
  setStaffDoesServices,
  setTicketStatus,
  spaErrorDetail,
  spaErrorHint,
  type AppointmentFilter,
  type AppointmentInput,
  type DayHours,
  type PetWeight,
  type SpaResourceInput,
  type TicketStatus,
} from "@bongcun/supabase/spa";
import type { RestfullMethod } from "@/types";
import { spaKeys } from "./keys";
import { notifyFailure, notifySuccess } from "./notify";

/** Failure toast that turns the booking rules (time taken, closed, past...) into text. */
const notifySpaFailure = (method: RestfullMethod, error: unknown) => {
  const hint = spaErrorHint(error);
  if (hint) {
    sendMessageToast("fail", method, "error", i18n.global.t(`spa.errors.${hint}`, { name: spaErrorDetail(error) }));
  } else notifyFailure(method, error);
};

// -------------------------------------------------------------- settings
export const useSpaResources = (branchId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => spaKeys.resources(unref(branchId) ?? "")),
    queryFn: () => listSpaResources(supabaseClient(), unref(branchId) as string),
    enabled: computed(() => !!unref(branchId)),
  });

export const useSaveSpaResource = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ input, id }: { input: SpaResourceInput; id?: string }) =>
      saveSpaResource(supabaseClient(), input, id),
    onSuccess: async (_data, { id }) => {
      await queryClient.invalidateQueries({ queryKey: spaKeys.all });
      notifySuccess(id ? "update" : "create");
    },
    onError: (error, { id }) => notifyFailure(id ? "update" : "create", error, i18n.global.t("spa.settings.tableName")),
  });
};

export const useWeekHours = (branchId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => spaKeys.hours(unref(branchId) ?? "")),
    queryFn: () => getWeekHours(supabaseClient(), unref(branchId) as string),
    enabled: computed(() => !!unref(branchId)),
  });

export const useSaveWeekHours = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ branchId, hours }: { branchId: string; hours: DayHours[] }) =>
      saveWeekHours(supabaseClient(), branchId, hours),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: spaKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifySpaFailure("update", error),
  });
};

export const useBranchStaff = (branchId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => spaKeys.staff(unref(branchId) ?? "")),
    queryFn: () => listBranchStaff(supabaseClient(), unref(branchId) as string),
    enabled: computed(() => !!unref(branchId)),
  });

export const useSetStaffDoesServices = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (args: { userId: string; branchId: string; value: boolean }) =>
      setStaffDoesServices(supabaseClient(), args),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: spaKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifyFailure("update", error),
  });
};

// ---------------------------------------------------------- appointments
export const useAppointmentsList = (
  branchId: MaybeRef<string | undefined>,
  page: MaybeRef<PageParams>,
  filter: MaybeRef<AppointmentFilter>
) =>
  useQuery({
    queryKey: computed(() => spaKeys.appointments(unref(branchId) ?? "", toPage(unref(page)), { ...unref(filter) })),
    queryFn: () =>
      listAppointments(supabaseClient(), unref(branchId) as string, toPage(unref(page)), { ...unref(filter) }),
    enabled: computed(() => !!unref(branchId)),
    placeholderData: keepPreviousData,
  });

export const useSaveAppointment = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ input, id }: { input: AppointmentInput; id?: string }) =>
      saveAppointment(supabaseClient(), input, id),
    onSuccess: async (_data, { id }) => {
      await queryClient.invalidateQueries({ queryKey: spaKeys.all });
      notifySuccess(id ? "update" : "create");
    },
    onError: (error, { id }) => notifySpaFailure(id ? "update" : "create", error),
  });
};

export const useCancelAppointment = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason?: string }) => cancelAppointment(supabaseClient(), id, reason),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: spaKeys.all });
      notifySuccess("update");
    },
    onError: (error) => notifySpaFailure("update", error),
  });
};

/** One appointment, kept fresh while its detail is open. */
export const useAppointment = (id: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => spaKeys.appointment(unref(id) ?? "")),
    queryFn: () => getAppointment(supabaseClient(), unref(id) as string),
    enabled: computed(() => !!unref(id)),
  });

const useSpaAction = <Variables>(action: (variables: Variables) => Promise<void>, method: RestfullMethod = "update") => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: action,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: spaKeys.all });
      notifySuccess(method);
    },
    onError: (error) => notifySpaFailure(method, error),
  });
};

export const useCheckInAppointment = () =>
  useSpaAction(({ id, weights }: { id: string; weights: PetWeight[] }) =>
    checkInAppointment(supabaseClient(), id, weights)
  );

export const useSetTicketStatus = () =>
  useSpaAction(({ ticketId, status }: { ticketId: string; status: TicketStatus }) =>
    setTicketStatus(supabaseClient(), ticketId, status)
  );

export const useMarkNoShow = () => useSpaAction((id: string) => markNoShow(supabaseClient(), id));

/** Finished spa tickets of a customer that are not on an invoice yet, for the POS cart. */
export const useBillableTickets = (branchId: MaybeRef<string | undefined>, customerId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => spaKeys.billable(unref(branchId) ?? "", unref(customerId) ?? "")),
    queryFn: () => listBillableTickets(supabaseClient(), unref(branchId) as string, unref(customerId) as string),
    enabled: computed(() => !!unref(branchId) && !!unref(customerId)),
  });

// ------------------------------------------------------------- day board
export const useDayBoard = (branchId: MaybeRef<string | undefined>, date: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => spaKeys.board(unref(branchId) ?? "", unref(date))),
    queryFn: () => getDayBoard(supabaseClient(), unref(branchId) as string, unref(date)),
    enabled: computed(() => !!unref(branchId)),
    // The day view stays open on the reception desk: pick up what the others book.
    refetchInterval: 30_000,
    refetchOnWindowFocus: true,
    placeholderData: keepPreviousData,
  });

/** Loads the appointment behind a board ticket when it is clicked. */
export const useFindAppointment = () =>
  useMutation({
    mutationFn: ({ branchId, code }: { branchId: string; code: string }) =>
      findAppointment(supabaseClient(), branchId, code),
    onError: (error) => notifyFailure("update", error),
  });
