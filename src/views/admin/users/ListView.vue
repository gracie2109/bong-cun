<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <User2 class="size-4 text-primary" />
      {{ $t("pageMeta.customers") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="relative top-10 space-y-5">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-2xl font-bold">{{ $t("pageMeta.customers") }}</h2>
          <p class="text-sm text-muted-foreground">{{ $t("pageFields.customers.subtitle") }}</p>
        </div>
        <Button @click="open = true">
          <UserPlus class="size-4 mr-2" />
          {{ $t("pageFields.customers.addNew") }}
        </Button>
      </div>

      <CustomerKpis :total="totalCustomers" :new-count="newCustomers" />

      <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            v-model="search"
            class="pl-9"
            :placeholder="$t('pageFields.customers.searchPlaceholder')"
          />
        </div>
        <Button
          type="button"
          size="sm"
          :variant="onlyNew ? 'default' : 'outline'"
          class="rounded-full"
          @click="onlyNew = !onlyNew"
        >
          {{ $t("pageFields.customers.filterNew", { days: NEW_CUSTOMER_DAYS }) }}
        </Button>
        <div class="flex items-center gap-2 text-sm text-muted-foreground">
          {{ $t("pageFields.customers.sortBy") }}
          <Select v-model="sort">
            <SelectTrigger class="w-44"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="option in sortOptions" :key="option" :value="option">
                {{ $t(`pageFields.customers.sort.${option}`) }}
              </SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      <div class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_26rem]">
        <CustomerTable
          :customers="customers"
          :stats="stats"
          :total="total"
          :page="pageData.pageIndex"
          :page-count="pageCount"
          :loading="usersQuery.isFetching.value"
          :selected-id="selected?.userId ?? null"
          @select="selectedId = $event"
          @page="pageData.pageIndex = $event"
        />
        <CustomerDetail
          :customer="selected"
          :orders="selectedOrders"
          :stats="statsOf(stats, selected?.userId ?? '')"
        />
      </div>
    </div>

    <Sheet :open="open" @update:open="handleReset">
      <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-xl">
        <SheetTitle class="sr-only">{{ $t("pageFields.customers.form.title") }}</SheetTitle>
        <SheetDescription class="sr-only">{{ $t("pageFields.customers.form.subtitle") }}</SheetDescription>
        <InfomationForm
          :form="form"
          :loading="loading"
          :list-user-group="[]"
          :addressModel="addressModel"
          @on-submit="submitHdl"
          @close-dialog="handleReset"
        />
      </SheetContent>
    </Sheet>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { refDebounced } from "@vueuse/core";
import { useForm } from "vee-validate";
import { Search, User2, UserPlus } from "lucide-vue-next";
import { Header, ContentWrap } from "@/views/admin/components";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetDescription, SheetTitle } from "@/components/ui/sheet";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { BASE_GENDER, INITIAL_PAGE_INDEX } from "@/lib/constants";
import { useOrdersByUsers } from "@/queries/orders";
import { useCreateUser, useUsersCount, useUsersList } from "@/queries/users";
import { USER_SORT, type UserListFilter, type UserSort } from "@/repositories/users";
import { initAddress, type IAddress } from "@/types/location.type";
import type { IUser } from "@/types/user.type";
import CustomerDetail from "./components/CustomerDetail.vue";
import CustomerKpis from "./components/CustomerKpis.vue";
import CustomerTable from "./components/CustomerTable.vue";
import InfomationForm from "./components/InfomationForm.vue";
import {
  NEW_CUSTOMER_DAYS,
  buildCustomerStats,
  newCustomerSince,
  statsOf,
} from "./customer-stats";

const CUSTOMER_ROLE = "customer";
const PAGE_SIZE = 8;
const SEARCH_DEBOUNCE_MS = 300;

const sortOptions = Object.values(USER_SORT);

const addressModel = ref<IAddress>({ ...initAddress });
const form = useForm<IUser>({
  initialValues: {
    province: initAddress,
    password: "",
    fullName: "",
    phoneNumber: "",
    photoURL: "",
    email: "",
    gender: BASE_GENDER[0].value,
    displayName: "",
    groupIds: null,
  },
});

const search = ref("");
const debouncedSearch = refDebounced(search, SEARCH_DEBOUNCE_MS);
const onlyNew = ref(false);
const sort = ref<UserSort>(USER_SORT.NEWEST);
const pageData = ref({ pageIndex: INITIAL_PAGE_INDEX, pageSize: PAGE_SIZE });

const filter = computed<UserListFilter>(() => ({
  role: CUSTOMER_ROLE,
  search: debouncedSearch.value,
  sort: sort.value,
  createdSince: onlyNew.value ? newCustomerSince() : undefined,
}));

watch(filter, () => (pageData.value.pageIndex = INITIAL_PAGE_INDEX));

const usersQuery = useUsersList(pageData, filter);
const customers = computed(() => usersQuery.data.value?.rows ?? []);
const total = computed(() => usersQuery.data.value?.total ?? 0);
const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));

const totalCustomers = useUsersCount({ role: CUSTOMER_ROLE }).data;
const newCustomers = useUsersCount(
  computed(() => ({ role: CUSTOMER_ROLE, createdSince: newCustomerSince() }))
).data;

const ordersQuery = useOrdersByUsers(computed(() => customers.value.map((c) => c.userId)));
const orders = computed(() => ordersQuery.data.value ?? []);
const stats = computed(() => buildCustomerStats(orders.value));

const selectedId = ref<string | null>(null);
const selected = computed(
  () => customers.value.find((c) => c.userId === selectedId.value) ?? customers.value[0] ?? null
);
const selectedOrders = computed(() => orders.value.filter((o) => o.userId === selected.value?.userId));

const createUser = useCreateUser();
const loading = computed(() => createUser.isPending.value);
const open = ref(false);

const handleReset = () => {
  form.resetForm();
  open.value = false;
};

const submitHdl = form.handleSubmit(async (value: any) => {
  try {
    await createUser.mutateAsync({
      email: value.email,
      password: value.password,
      displayName: value.displayName,
      fullName: value.fullName,
      phoneNumber: value.phoneNumber,
      gender: value.gender,
      address: value.province,
      photoURL: value.photoURL,
    });
  } catch {
    return; // the mutation already showed the failure toast; keep the dialog open
  }
  handleReset();
});
</script>
