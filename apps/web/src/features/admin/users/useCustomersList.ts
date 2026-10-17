import { computed, ref } from "vue";
import { usePagedList } from "@/composables/usePagedList";
import { useListFilters } from "@/composables/useListFilters";
import { SEARCH_DEBOUNCE_FAST_MS } from "@/lib/listing";
import { useOrdersByUsers } from "@/features/admin/users/queries/orders";
import { useUsersCount, useUsersList } from "@/features/admin/users/queries/users";
import { USER_SORT, type UserListFilter, type UserSort } from "@bongcun/supabase/users";
import { CUSTOMER_ROLE } from "../settings/rbac";
import { buildCustomerStats, newCustomerSince } from "./customer-stats";

const PAGE_SIZE = 8;

/** The customers list: search, filters and paging, with their order stats and the one selected. */
export const useCustomersList = () => {
  const onlyNew = ref(false);
  // "New customers" is a chip next to the search box, so it applies at once; the sort is in the popover.
  const list = useListFilters({
    pageSize: PAGE_SIZE,
    debounceMs: SEARCH_DEBOUNCE_FAST_MS,
    defaults: { sort: USER_SORT.NEWEST as UserSort },
    quick: { onlyNew: { value: onlyNew, default: false } },
  });
  const { applied, debouncedSearch, page } = list;

  const filter = computed<UserListFilter>(() => ({
    role: CUSTOMER_ROLE,
    search: debouncedSearch.value,
    sort: applied.value.sort,
    createdSince: onlyNew.value ? newCustomerSince() : undefined,
  }));

  const usersQuery = useUsersList(page, filter);
  const { rows: customers, total, pageCount } = usePagedList(usersQuery, page);

  const totalCustomers = useUsersCount({ role: CUSTOMER_ROLE }).data;
  const newCustomers = useUsersCount(
    computed(() => ({ role: CUSTOMER_ROLE, createdSince: newCustomerSince() }))
  ).data;

  const ordersQuery = useOrdersByUsers(computed(() => customers.value.map((c) => c.userId)));
  const orders = computed(() => ordersQuery.data.value ?? []);
  const stats = computed(() => buildCustomerStats(orders.value));

  // The first customer is selected until another is picked.
  const selectedId = ref<string | null>(null);
  const selected = computed(
    () => customers.value.find((c) => c.userId === selectedId.value) ?? customers.value[0] ?? null
  );
  const selectedOrders = computed(() => orders.value.filter((o) => o.userId === selected.value?.userId));

  return {
    ...list,
    onlyNew,
    usersQuery,
    customers,
    total,
    pageCount,
    fetching: usersQuery.isFetching,
    totalCustomers,
    newCustomers,
    stats,
    selectedId,
    selected,
    selectedOrders,
    filter,
  };
};
