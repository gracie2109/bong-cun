import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import { useBoardingStay, useMarkBoardingNoShow } from "@/queries/boarding";
import { useAuthStore } from "@/stores";
import type { StayPet } from "@bongcun/core/boarding";

/** The stay of the route with what the signed-in staff may do to it, and which dialog is open. */
export const useStayDetail = () => {
  const route = useRoute();
  const auth = useAuthStore();
  const stayId = computed(() => String(route.params.stayId));

  const stayQuery = useBoardingStay(stayId);
  const stay = computed(() => stayQuery.data.value ?? null);
  const activePets = computed(() => (stay.value?.pets ?? []).filter((pet) => pet.status === "active"));
  const isIn = computed(() => stay.value?.status === "checked_in");

  const canCreate = computed(() => auth.can("boarding", "CREATE"));
  const canUpdate = computed(() => auth.can("boarding", "UPDATE"));

  const editOpen = ref(false);
  const checkInOpen = ref(false);
  const extendOpen = ref(false);
  const checkOutOpen = ref(false);
  /** The pet whose kennel is being changed. */
  const movePet = ref<StayPet | null>(null);

  const noShow = useMarkBoardingNoShow();
  const markNoShow = () => stay.value && noShow.mutate(stay.value.id);

  return {
    stayQuery, stay, activePets, isIn, canCreate, canUpdate,
    editOpen, checkInOpen, extendOpen, checkOutOpen, movePet, markNoShow,
  };
};
