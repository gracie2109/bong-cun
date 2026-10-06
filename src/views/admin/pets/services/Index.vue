<template>
  <PageTitle />
  <ContentWrap>
    <SubMenu />
    <div class="bg-white min-h-svh p-5 space-y-6 mt-20">
  
      <DataTable
        :headerAdvanced="headerAdvanced"
        :data="petServices"
        :columns="columns"
        :page-count="pageCount"
        :page-data="pageData"
        :saveColumnVisible="{
          name: 'petServices',
          isRemeber: true,
        }"
        :add-new-handle="{
          content: null,
          type: 'function',
        }"
        :show-search="true"
        @clear-filter="clearFilter"
        @on-reset="onReset"
        @clearFilter="clearFilter"
        @set-open="setOpen"
        @handle-page-change="loadDataForPage"
        @update-page-size="updatePageSize"
      />
    </div>
  </ContentWrap>

  <DialogConfirm
    @change-open="
      () => {
        selectedItem = null;
        open = !open;
      }
    "
    :open="open && selectedItem && !rowEditSelected"
    :title="selectedItem?.name"
    @cancel="
      () => {
        selectedItem = null;
        open = false;
      }
    "
    @handleOk="handleDelete"
  />

  <ModalCreateService
    :title="$t('common.create')"
    :handle-open="open && !selectedItem"
    @updateOpen="(vl) => {
       open = vl;
       rowEditSelected = null;
    }"
    :elSelect="rowEditSelected"
    @setElSelect="setElSelect"
  />
</template>

<script lang="ts" setup>
import { ContentWrap } from "@/views/admin/components";

import { h, reactive, ref } from "vue";
import { useDeletePetService, usePetServicesList } from "@/queries/petServices";
import usePagedRows from "@/composables/usePagedRows";
import { formatDateTime, formatPrice } from "@/lib/utils";
import { type IHeaderAdvanced, type T_ROW_FUNCTION } from "@/types";
import type { ColumnDef, PaginationState } from "@tanstack/vue-table";

import { DialogConfirm, DataTable } from "@/components/common";
import DataTableColumnHeader from "@/components/common/DataTable/DataTableColumnHeader.vue";
import { HEADER_ADVANCE_FUNCTION, INITIAL_PAGE_INDEX } from "@/lib/constants";
import RowFunction from "../components/RowFunction.vue";
import PageTitle from "../PageTitle.vue";
import ModalCreateService from "../components/ModalCreateService.vue";
import { contents as unit, type } from "@/data/pet-service.json";
import { useI18n } from "vue-i18n";
import SubMenu from "../components/SubMenu.vue";

const { locale } = useI18n();
const selectedItem = ref();
const rowEditSelected = ref();
const mode = ref();

const pageData = ref<PaginationState>({
  pageIndex: INITIAL_PAGE_INDEX,
  pageSize: 500,
});

const servicesQuery = usePetServicesList(pageData);
const { rows: petServices, total: pageCount } = usePagedRows(servicesQuery, pageData);
const deleteService = useDeletePetService();

const columns: ColumnDef<any>[] = reactive([
  {
    accessorKey: "index",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "#" }),

    cell: ({ row }) => {
      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("index")
      );
    },
  },
  {
    accessorKey: "name",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "Name" }),
    cell: ({ row }) => {
      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("name")
      );
    },
  },
  {
    accessorKey: "type",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "Type" }),
    cell: ({ row }) => {
      const slT = row.getValue("type") as string;
      const petType = type.find((i) => i.id === slT)?.lang as any;

      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        petType[locale.value]
      );
    },
  },
  {
    accessorKey: "unit",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "Unit" }),
    cell: ({ row }) => {
      const slT = row.getValue("unit") as string;
      const petType = (unit.find((i) => i.id === slT)?.lang as any) || "";

      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        petType[locale.value]
      );
    },
  },
  {
    accessorKey: "isShow",
    header: ({ column }) =>
      h(DataTableColumnHeader, { column, title: "Service single" }),
    cell: ({ row }) => {
      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("isShow")
      );
    },
  },
  {
    accessorKey: "generalPrice",
    header: ({ column }) =>
      h(DataTableColumnHeader, { column, title: "General Price" }),
    cell: ({ row }) => {
      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        formatPrice(row.getValue("generalPrice") || "")
      );
    },
  },
  {
    accessorKey: "desc",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "Desc" }),
    cell: ({ row }) => {
      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("desc")
      );
    },
  },

  {
    accessorKey: "createdAt",
    header: ({ column }) =>
      h(DataTableColumnHeader, { column, title: "Created At" }),
    cell: ({ row }) => {
      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        formatDateTime(row.getValue("createdAt"))
      );
    },
  },
  {
    id: "function",
    accessorKey: "function",
    header: ({ column }) =>
      h(DataTableColumnHeader, { column, title: "Function" }),
    cell: ({ row }) =>
      h(RowFunction, {
        row,
        onClick: (item: any) => {
          handleActionRow(item);
        },
      }),
  },
]);

const headerAdvanced = reactive<IHeaderAdvanced[]>([
  HEADER_ADVANCE_FUNCTION.SETTING_COLUMN,
  HEADER_ADVANCE_FUNCTION.ADD_NEW,
]);

const open = ref(false);

function handleActionRow({
  action,
  row,
}: {
  action: T_ROW_FUNCTION;
  row: any;
}) {
  if (action.isShow) {
    if (action.id === "DELETE") {
      deleteItem(row);
    }

    if (action.id === "EDIT") {
      open.value = true;
      rowEditSelected.value = row;
    }
  }
}

function deleteItem(val: any) {
  selectedItem.value = val;
  open.value = true;
  mode.value = "delete";
}
async function handleDelete() {
  try {
    await deleteService.mutateAsync(selectedItem.value.id);
  } catch {
    // the mutation already showed the failure toast
  } finally {
    setOpen();
    selectedItem.value = null;
  }
}

function onReset() {
  alert("reset");
}
function clearFilter() {
  alert("clearFilter");
}
function setOpen() {
  open.value = !open.value;
}
function setElSelect() {
  selectedItem.value =null
}


function updatePageSize(newPs: number) {
  pageData.value.pageSize = +newPs;
  pageData.value.pageIndex = INITIAL_PAGE_INDEX;
}

function loadDataForPage(page: number) {
  pageData.value.pageIndex = page;
}
</script>
