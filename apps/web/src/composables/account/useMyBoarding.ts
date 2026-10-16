import { computed, ref, watch } from "vue";
import { useMyProfile } from "@/queries/account";
import { useMyBoardingStays } from "@/queries/accountBoarding";
import type { BoardingScope } from "@bongcun/core/account";

const PAGE_SIZE = 10;

/** The "Lưu trú" page: upcoming / current / past tabs and paging. */
export const useMyBoarding = () => {
  const profile = useMyProfile();
  const hasCustomer = computed(() => Boolean(profile.data.value?.customerId));

  const scope = ref<BoardingScope>("current");
  const page = ref(1);
  watch(scope, () => (page.value = 1));

  const query = useMyBoardingStays(scope, page, PAGE_SIZE, hasCustomer);
  const rows = computed(() => query.data.value?.rows ?? []);
  const total = computed(() => query.data.value?.total ?? 0);
  const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));

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
  };
};
