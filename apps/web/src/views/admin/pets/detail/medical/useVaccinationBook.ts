import { computed, ref, type Ref } from "vue";
import { usePetBook, useVoidVaccine } from "@/queries/vaccinations";
import { useAuthStore } from "@/stores";
import type { VaccineDose } from "@bongcun/core/medical";

/** A pet's e-book with what the signed-in staff may do to it. */
export const useVaccinationBook = (petId: Ref<string>) => {
  const auth = useAuthStore();
  const bookQuery = usePetBook(petId);
  const book = computed(() => bookQuery.data.value ?? []);

  const canAdd = computed(() => auth.can("medical", "CREATE"));
  const canUpdate = computed(() => auth.can("medical", "UPDATE"));
  /** Only a shot typed in from elsewhere can be struck out here; a clinic shot goes through its visit. */
  const canVoid = (dose: VaccineDose) => canUpdate.value && dose.isExternal;

  const addOpen = ref(false);
  const voiding = ref<VaccineDose | null>(null);
  const voidMutation = useVoidVaccine();

  const confirmVoid = async (reason: string) => {
    if (!voiding.value) return;
    try {
      await voidMutation.mutateAsync({ id: voiding.value.id, reason });
      voiding.value = null;
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return { bookQuery, book, canAdd, canVoid, addOpen, voiding, confirmVoid, voidBusy: voidMutation.isPending };
};
