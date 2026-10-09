<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <User2 class="size-4 text-primary" />
      {{ $t("pageMeta.customers") }}
    </h1>
  </Header>

  <ContentWrap fill="xl">
    <div class="space-y-5 xl:flex xl:min-h-0 xl:flex-1 xl:flex-col xl:gap-5 xl:space-y-0">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-2xl font-bold">{{ $t("pageMeta.customers") }}</h2>
          <p class="text-sm text-muted-foreground">{{ $t("pageFields.customers.subtitle") }}</p>
        </div>
        <Button v-if="canCreate" @click="createOpen = true">
          <UserPlus class="size-4 mr-2" />
          {{ $t("pageFields.customers.addNew") }}
        </Button>
      </div>

      <CustomerKpis :total="totalCustomers" :new-count="newCustomers" />

      <CustomersFilterBar v-model:search="search" v-model:only-new="onlyNew" v-model:sort="sort" />

      <div class="grid gap-5 xl:min-h-0 xl:flex-1 xl:grid-cols-[minmax(0,1fr)_26rem] xl:grid-rows-[minmax(0,1fr)]">
        <CustomerTable
          :customers="customers"
          :stats="stats"
          :total="total"
          :page="page.pageIndex"
          :page-size="page.pageSize"
          :page-count="pageCount"
          :loading="fetching"
          :selected-id="selected?.userId ?? null"
          @select="selectedId = $event"
          @page="page.pageIndex = $event"
          @page-size="page.pageSize = $event"
        />
        <CustomerDetail
          class="xl:max-h-full xl:overflow-y-auto"
          :customer="selected"
          :orders="selectedOrders"
          :stats="statsOf(stats, selected?.userId ?? '')"
        />
      </div>
    </div>

    <CustomerCreateSheet v-model:open="createOpen" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { User2, UserPlus } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { usePermission } from "@/composables/usePermission";
import { ContentWrap, Header } from "@/views/admin/components";
import CustomerCreateSheet from "./CustomerCreateSheet.vue";
import CustomerDetail from "./components/CustomerDetail.vue";
import CustomerKpis from "./components/CustomerKpis.vue";
import CustomerTable from "./components/CustomerTable.vue";
import CustomersFilterBar from "./CustomersFilterBar.vue";
import { statsOf } from "./customer-stats";
import { useCustomersList } from "./useCustomersList";

const { canCreate } = usePermission("users");
const createOpen = ref(false);

const {
  search,
  onlyNew,
  sort,
  page,
  customers,
  total,
  pageCount,
  fetching,
  totalCustomers,
  newCustomers,
  stats,
  selectedId,
  selected,
  selectedOrders,
} = useCustomersList();
</script>
