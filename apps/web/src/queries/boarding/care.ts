import { useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  addBoardingExtra,
  addCareLog,
  checkInBoarding,
  checkOutBoarding,
  deleteCareLog,
  extendBoardingStay,
  getCheckoutPreview,
  listBillableBoarding,
  removeBoardingExtra,
} from "@/repositories/boarding";
import type { CareLogInput, CheckInPetInput } from "@bongcun/core/boarding";
import { boardingKeys } from "../keys";
import { useBoardingAction } from "./action";

// ------------------------------------------------------- care, check-in/out
export const useAddCareLog = () =>
  useBoardingAction(({ stayPetId, input }: { stayPetId: string; input: CareLogInput }) =>
    addCareLog(supabaseClient(), stayPetId, input), "create");

export const useDeleteCareLog = () => useBoardingAction((id: string) => deleteCareLog(supabaseClient(), id), "delete");

export const useAddBoardingExtra = () =>
  useBoardingAction(({ stayPetId, serviceId, qty }: { stayPetId: string; serviceId: string; qty: number }) =>
    addBoardingExtra(supabaseClient(), stayPetId, serviceId, qty), "create");

export const useRemoveBoardingExtra = () =>
  useBoardingAction((id: string) => removeBoardingExtra(supabaseClient(), id), "delete");

export const useCheckInBoarding = () =>
  useBoardingAction(({ id, pets, emergencyPhone }: { id: string; pets: CheckInPetInput[]; emergencyPhone: string }) =>
    checkInBoarding(supabaseClient(), id, pets, emergencyPhone));

export const useExtendBoardingStay = () =>
  useBoardingAction(({ id, plannedOutAt }: { id: string; plannedOutAt: string }) =>
    extendBoardingStay(supabaseClient(), id, plannedOutAt));

export const useCheckOutBoarding = () =>
  useBoardingAction(({ id, returnedPetIds }: { id: string; returnedPetIds: string[] }) =>
    checkOutBoarding(supabaseClient(), id, returnedPetIds));

/** What leaving now would cost; read fresh every time the dialog opens. */
export const useCheckoutPreview = (id: MaybeRef<string | undefined>, enabled: MaybeRef<boolean>) =>
  useQuery({
    queryKey: computed(() => boardingKeys.checkoutPreview(unref(id) ?? "")),
    queryFn: () => getCheckoutPreview(supabaseClient(), unref(id) as string),
    enabled: computed(() => !!unref(id) && unref(enabled)),
    staleTime: 0,
    gcTime: 0,
  });

// The checked-out stays of a customer that wait for payment in the POS.
export const useBillableBoarding = (branchId: MaybeRef<string | undefined>, customerId: MaybeRef<string | undefined>) =>
  useQuery({
    queryKey: computed(() => boardingKeys.billable(unref(branchId) ?? "", unref(customerId) ?? "")),
    queryFn: () => listBillableBoarding(supabaseClient(), unref(branchId) as string, unref(customerId) as string),
    enabled: computed(() => !!unref(branchId) && !!unref(customerId)),
  });
