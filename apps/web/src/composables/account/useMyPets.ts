import { computed } from "vue";
import { useMyPets as useMyPetsQuery, useMyProfile } from "@/queries/account";

/** The "my pets" page: a read-only list. Only the shop adds, edits or removes pets. */
export const useMyPets = () => {
  const profile = useMyProfile();
  const hasCustomer = computed(() => Boolean(profile.data.value?.customerId));
  const petsQuery = useMyPetsQuery(hasCustomer);

  return {
    pets: computed(() => petsQuery.data.value ?? []),
    loading: computed(() => profile.isLoading.value || (hasCustomer.value && petsQuery.isLoading.value)),
    failed: computed(() => profile.isError.value || petsQuery.isError.value),
    retry: () => {
      void profile.refetch();
      void petsQuery.refetch();
    },
    hasCustomer,
  };
};
