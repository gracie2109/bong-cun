import { computed, reactive, ref } from "vue";
import { useHideMyPet, useMyPets as useMyPetsQuery, useMyProfile, useSaveMyPet } from "@/queries/account";
import { useSpeciesOptions } from "@/queries/species";
import type { MyPet } from "@/types/account";
import { emptyPetForm, normalizePetForm, petErrors, petToForm, type PetForm } from "@/utils/account/pet";

/** The "my pets" page: the list, the edit dialog and hiding a pet. Only the shop adds pets. */
export const useMyPets = () => {
  const profile = useMyProfile();
  const hasCustomer = computed(() => Boolean(profile.data.value?.customerId));
  const petsQuery = useMyPetsQuery(hasCustomer);
  const species = useSpeciesOptions();
  const saveMutation = useSaveMyPet();
  const hideMutation = useHideMyPet();

  const open = ref(false);
  const editingId = ref<string | null>(null);
  const submitted = ref(false);
  const form = reactive<PetForm>(emptyPetForm());
  const errors = computed(() => petErrors(form));
  const toHide = ref<MyPet | null>(null);

  const openEdit = (pet: MyPet) => {
    Object.assign(form, petToForm(pet));
    editingId.value = pet.id;
    submitted.value = false;
    open.value = true;
  };

  const submit = async () => {
    submitted.value = true;
    const id = editingId.value;
    if (!id || Object.keys(errors.value).length > 0) return;
    try {
      await saveMutation.mutateAsync({ input: normalizePetForm(form), id });
      open.value = false;
    } catch {
      // the mutation already showed the failure toast
    }
  };

  const confirmHide = async () => {
    const pet = toHide.value;
    toHide.value = null;
    if (!pet) return;
    try {
      await hideMutation.mutateAsync(pet.id);
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return {
    pets: computed(() => petsQuery.data.value ?? []),
    species: computed(() => species.data.value ?? []),
    loading: computed(() => profile.isLoading.value || (hasCustomer.value && petsQuery.isLoading.value)),
    failed: computed(() => profile.isError.value || petsQuery.isError.value),
    retry: () => {
      void profile.refetch();
      void petsQuery.refetch();
    },
    hasCustomer,
    open,
    editingId,
    form,
    errors,
    submitted,
    saving: saveMutation.isPending,
    openEdit,
    submit,
    toHide,
    confirmHide,
  };
};
