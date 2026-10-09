<template>
  <div>
    <Header>
      <h1 class="font-semibold flex items-center gap-2">
        <CalendarDays class="size-4 text-primary" />
        List Schedule ({{ totalRecord }})
      </h1>
    </Header>
    <ContentWrap>
      <div>
        <DataTable
          :headerAdvanced="headerAdvanced"
          :data="orders"
          :columns="columns"
          :page-count="totalRecord"
          :page-data="pageData"
          :saveColumnVisible="{ name: 'customers', isRemeber: true }"
          :add-new-handle="{ content: null, type: 'function' }"
          :show-search="true"
          @on-input="onInput"
          @change-date="handleDate"
        />
      </div>
    </ContentWrap>
  </div>
</template>

<script lang="ts" setup>
import { reactive, ref } from "vue";
import { useI18n } from "vue-i18n";
import { CalendarDays } from "lucide-vue-next";
import type { PaginationState } from "@tanstack/vue-table";
import { DataTable } from "@/components/common";
import usePagedRows from "@/composables/usePagedRows";
import { HEADER_ADVANCE_FUNCTION, INITIAL_PAGE_INDEX, TIME_OPTIONS } from "@/lib/constants";
import { useOrdersList } from "@/queries/orders";
import type { IHeaderAdvanced } from "@/types";
import ContentWrap from "@/views/admin/components/ContentWrap.vue";
import Header from "@/views/admin/components/Header.vue";
import { buildOrderColumns } from "./orderColumns";

const PAGE_SIZE = 25;

const date = ref(TIME_OPTIONS[0]["value"]);

const headerAdvanced = reactive<IHeaderAdvanced[]>([
  HEADER_ADVANCE_FUNCTION.SETTING_COLUMN,
  HEADER_ADVANCE_FUNCTION.ADD_NEW
]);

const pageData = ref<PaginationState>({
  pageIndex: INITIAL_PAGE_INDEX,
  pageSize: PAGE_SIZE
});

// Exact phone-number search, as the search box always intended.
const phoneNumber = ref<string | undefined>(undefined);
const ordersQuery = useOrdersList(pageData, phoneNumber);
const { rows: orders, total: totalRecord } = usePagedRows(ordersQuery, pageData);
const { locale } = useI18n();

const columns = reactive(buildOrderColumns(locale));

const onInput = (vl: string | number) => {
  const text = String(vl).trim();
  phoneNumber.value = text.length > 0 ? text : undefined;
  pageData.value.pageIndex = INITIAL_PAGE_INDEX;
};

const handleDate = (vl: any) => {
  date.value = vl;
};
</script>
