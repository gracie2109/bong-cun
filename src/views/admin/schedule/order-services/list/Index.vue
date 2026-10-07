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
import Header from "@/views/admin/components/Header.vue";
import ContentWrap from "@/views/admin/components/ContentWrap.vue";
import { reactive, ref } from "vue";
import { useOrdersList } from "@/queries/orders";
import usePagedRows from "@/composables/usePagedRows";
import {
  HEADER_ADVANCE_FUNCTION,
  INITIAL_PAGE_INDEX,
  TIME_OPTIONS
} from "@/lib/constants";
import { DataTable } from "@/components/common";
import type { ColumnDef, PaginationState } from "@tanstack/vue-table";
import DataTableColumnHeader from "@/components/common/DataTable/DataTableColumnHeader.vue";
import { h } from "vue";
import type { IHeaderAdvanced } from "@/types";
import { status } from "@/data/order-services-status.json";
import { useI18n } from "vue-i18n";
import RowAction from "./components/RowAction.vue";
import { CalendarDays } from "lucide-vue-next";
import { formatDateTime } from "@/lib/utils";

const date = ref(TIME_OPTIONS[0]["value"]);

const headerAdvanced = reactive<IHeaderAdvanced[]>([
  HEADER_ADVANCE_FUNCTION.SETTING_COLUMN,
  HEADER_ADVANCE_FUNCTION.ADD_NEW
]);

const pageData = ref<PaginationState>({
  pageIndex: INITIAL_PAGE_INDEX,
  pageSize: 25
});

// Exact phone-number search, as the search box always intended.
const phoneNumber = ref<string | undefined>(undefined);
const ordersQuery = useOrdersList(pageData, phoneNumber);
const { rows: orders, total: totalRecord } = usePagedRows(ordersQuery, pageData);
const { locale } = useI18n();

const onInput = (vl: string | number) => {
  const text = String(vl).trim();
  phoneNumber.value = text.length > 0 ? text : undefined;
  pageData.value.pageIndex = INITIAL_PAGE_INDEX;
};

const handleDate = (vl: any) => {
  date.value = vl;
};

const columns: ColumnDef<any>[] = reactive([
  {
    accessorKey: "index",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "#" }),
    cell: ({ row }) =>
      h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("index")
      )
  },
  {
    accessorKey: "name",
    header: ({ column }) =>
      h(DataTableColumnHeader, { column, title: "Username" }),
    cell: ({ row }) =>
      h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("name")
      )
  },
  {
    accessorKey: "phoneNumber",
    header: ({ column }) =>
      h(DataTableColumnHeader, { column, title: "Phone Number" }),
    cell: ({ row }) =>
      h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("phoneNumber")
      )
  },
  {
    accessorKey: "petNum",
    header: ({ column }) =>
      h(DataTableColumnHeader, { column, title: "Pet Number" }),
    cell: ({ row }) =>
      h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("petNum")
      )
  },
  {
    accessorKey: "time",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "Time" }),
    cell: ({ row }) =>
      h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        formatDateTime(row.getValue("time") as string)
      )
  },
  {
    accessorKey: "services",
    header: ({ column }) =>
      h(DataTableColumnHeader, { column, title: "Services" }),
    cell: ({ row }) => {
      const services = (row.getValue("services") as any[])
        ?.map((i, index) => {
          return index < row.original.services.length - 1
            ? `${i?.name} + `
            : i?.name;
        })
        .join(""); // Join services to a string
      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        services
      );
    }
  },
  {
    accessorKey: "status",
    header: ({ column }) =>
      h(DataTableColumnHeader, { column, title: "Status" }),
    cell: ({ row }) => {
      const stt = (
        status.find((i) => i.value === row.getValue("status")) as any
      )?.name?.[String(locale.value)];
      return h("span", { class: "max-w-[500px] truncate font-medium" }, stt);
    }
  },
  {
    id: "function",
    accessorKey: "function",
    header: ({ column }) =>
      h(DataTableColumnHeader, { column, title: "Function" }),
    cell: ({ row }) =>
      h(RowAction, {
        row
      })
  }
]);
</script>
