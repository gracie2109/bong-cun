import { computed, ref } from "vue";
import { usePagedList } from "@/composables/usePagedList";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { SEARCH_DEBOUNCE_FAST_MS } from "@/lib/listing";
import { useOrdersByUsers } from "@/queries/orders";
import { useUsersCount, useUsersList } from "@/queries/users";
import { USER_SORT, type UserListFilter, type UserSort } from "@/repositories/users";
import { CUSTOMER_ROLE } from "../settings/rbac";
import { buildCustomerStats, newCustomerSince } from "./customer-stats";

const PAGE_SIZE = 8;

/** The customers list: search, filters and paging, with their order stats and the one selected. */
export const useCustomersList = () => {
  const onlyNew = ref(false);
  const sort = ref<UserSort>(USER_SORT.NEWEST);
  const { search, debouncedSearch, page } = usePagedSearch({
    pageSize: PAGE_SIZE,
    debounceMs: SEARCH_DEBOUNCE_FAST_MS,
    resetOn: [onlyNew, sort],
  });

  const filter = computed<UserListFilter>(() => ({
    role: CUSTOMER_ROLE,
    search: debouncedSearch.value,
    sort: sort.value,
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
    search,
    onlyNew,
    sort,
    page,
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
  };
};
