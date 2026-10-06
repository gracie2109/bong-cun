<template>
  <PageTitle />

  <ContentWrap>
    <div class="relative">
      <SubMenu />
      <div class="relative top-20 z-30">
        <DataTable
          :headerAdvanced="headerAdvanced"
          :data="pets"
          :columns="columns"
          :page-count="pageCount"
          :page-data="pageData"
          :saveColumnVisible="{
            name: 'pets',
            isRemeber: false,
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
        >
        </DataTable>
      </div>
    </div>
  </ContentWrap>
  <ServiceForm
    @change-open="() => (open = !open)"
    :open="open && !selectedItem"
    :rowEditting="rowEditSelected"
  />
  <DialogConfirm
    @change-open="
      () => {
        selectedItem = null;
        open = !open;
      }
    "
    :open="open && selectedItem"
    :title="selectedItem?.name"
    @cancel="
      () => {
        selectedItem = null;
        open = false;
      }
    "
    @handleOk="handleDelete"
  />
</template>

<script lang="ts" setup>
import { ContentWrap } from "@/views/admin/components";
import ServiceForm from "./components/Form.vue";
import { h, reactive, ref } from "vue";
import { useDeletePet, usePetsList } from "@/queries/pets";
import usePagedRows from "@/composables/usePagedRows";
import { formatDateTime } from "@/lib/utils";
import { type IHeaderAdvanced, type T_ROW_FUNCTION } from "@/types";
import type { ColumnDef, PaginationState } from "@tanstack/vue-table";

import { DialogConfirm, DataTable } from "@/components/common";
import DataTableColumnHeader from "@/components/common/DataTable/DataTableColumnHeader.vue";
import { HEADER_ADVANCE_FUNCTION, INITIAL_PAGE_INDEX } from "@/lib/constants";
import { Icon } from "@iconify/vue";
import RowFunction from "./components/RowFunction.vue";
import PageTitle from "./PageTitle.vue";
import { useI18n } from "vue-i18n";
import SubMenu from "./components/SubMenu.vue";

const selectedItem = ref();
const mode = ref();
const rowEditSelected = ref();
const pageData = ref<PaginationState>({
  pageIndex: INITIAL_PAGE_INDEX,
  pageSize: 5,
});

const petsQuery = usePetsList(pageData);
const { rows: pets, total: pageCount } = usePagedRows(petsQuery, pageData);
const deletePet = useDeletePet();

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
    accessorKey: "icon",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "Icon" }),
    cell: ({ row }) =>
      h(Icon, {
        row,
        icon: row.getValue("icon") as string,
      }),
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
  HEADER_ADVANCE_FUNCTION.ADD_NEW,
  HEADER_ADVANCE_FUNCTION.SETTING_COLUMN,
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
    await deletePet.mutateAsync(selectedItem.value.id);
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

function updatePageSize(newPs: number) {
  pageData.value.pageSize = +newPs;
  pageData.value.pageIndex = INITIAL_PAGE_INDEX;
}

function loadDataForPage(page: number) {
  pageData.value.pageIndex = page;
}
</script>
