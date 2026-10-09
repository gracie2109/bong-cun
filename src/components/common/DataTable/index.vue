<template>
  <div class="flex min-h-0 w-full flex-1 flex-col gap-3">
    <SearchWrap v-if="props.showSearch || props.showSearch === undefined">
      <SearchView
        v-if="
          props.addNewHandle && props.saveColumnVisible && props.headerAdvanced
        "
        placeholder="Search by store"
        @reset="() => $emit('onReset')"
        @clear-filter="() => $emit('clearFilter')"
        @setOpen="() => $emit('setOpen')"
        :addNew="props.addNewHandle"
        :table="table"
        :saveColumnVisible="props.saveColumnVisible"
        :headerAdvanced="props.headerAdvanced"
        :buttonFunctions="props.buttonFunctions"
        @on-input="(vl) => $emit('onInput', vl)"
        @change-date="(vl) => $emit('changeDate', vl)"
      >
      </SearchView>
    </SearchWrap>

    <PagedTableCard
      id="showTable"
      v-model:page="paging.pageIndex"
      v-model:page-size="paging.pageSize"
      class="min-h-0 flex-1"
      :page-count="Math.max(1, Math.ceil((props.pageCount || 0) / (paging.pageSize || 1)))"
      :count="table.getRowModel().rows.length"
      :total="props.pageCount || 0"
      @update:page="(vl) => emits('handlePageChange', vl)"
    >
      <Table>
        <TableHeader>
          <TableRow v-for="headerGroup in table.getHeaderGroups()" :key="headerGroup.id">
            <TableHead v-for="header in headerGroup.headers" :key="header.id" class="font-semibold text-foreground">
              <FlexRender
                v-if="!header.isPlaceholder"
                :props="header.getContext()"
                :render="header.column.columnDef.header"
              />
            </TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow
            v-for="row in table.getRowModel().rows"
            :key="row.id"
            :data-state="row.getIsSelected() && 'selected'"
          >
            <TableCell v-for="cell in row.getVisibleCells()" :key="cell.id">
              <FlexRender :props="cell.getContext()" :render="cell.column.columnDef.cell" />
            </TableCell>
          </TableRow>
          <TableStateRows
            :colspan="columns.length"
            :pending="false"
            :empty="table.getRowModel().rows.length === 0"
            :empty-text="$t('petCare.common.noData')"
          />
        </TableBody>
      </Table>
    </PagedTableCard>
  </div>
</template>

<script lang="ts" setup>
import {
  FlexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  getExpandedRowModel,
  useVueTable,
  _getVisibleLeafColumns
} from "@tanstack/vue-table";

import type {
  ColumnDef,
  ColumnFiltersState,
  SortingState,
  VisibilityState,
  PaginationState
} from "@tanstack/vue-table";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow
} from "@/components/ui/table";

import { valueUpdater } from "@/lib/utils";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { computed, onMounted, reactive, ref, watchEffect } from "vue";
import SearchWrap from "@/views/admin/components/SearchWrap.vue";
import SearchView from "../SearchView.vue";
import { LOCAL_STORAGE_KEY } from "@/lib/constants";
import { type IHeaderAdvanced } from "@/types";

const sorting = ref<SortingState>([]);
const columnFilters = ref<ColumnFiltersState>([]);
const rowSelection = ref({});
const columnVisibility = ref<VisibilityState>({});
type TAddNewHandle = {
  type: "function" | "link";
  content: null | string;
};
const props = defineProps<{
  data: any[];
  columns: ColumnDef<any>[];
  pageCount?: number;
  pageData?: PaginationState;
  saveColumnVisible?: {
    name: string;
    isRemeber: boolean;
  };
  headerAdvanced?: IHeaderAdvanced[];
  addNewHandle?: TAddNewHandle;
  showSearch?: boolean;
  buttonFunctions?: any;
}>();

const emits = defineEmits([
  "handlePageChange",
  "onReset",
  "clearFilter",
  "setOpen",
  "updatePageSize",
  "onInput",
  "changeDate"
]);

const table = useVueTable({
  get data() {
    return props.data;
  },
  get columns() {
    return props.columns;
  },
  getCoreRowModel: getCoreRowModel(),
  manualPagination: true,
  getSortedRowModel: getSortedRowModel(),
  getFilteredRowModel: getFilteredRowModel(),
  getExpandedRowModel: getExpandedRowModel(),
  onSortingChange: (updaterOrValue) => valueUpdater(updaterOrValue, sorting),
  onColumnFiltersChange: (updaterOrValue) =>
    valueUpdater(updaterOrValue, columnFilters),
  onColumnVisibilityChange: (updaterOrValue) =>
    valueUpdater(updaterOrValue, columnVisibility),
  onRowSelectionChange: (updaterOrValue) =>
    valueUpdater(updaterOrValue, rowSelection),
  state: {
    get sorting() {
      return sorting.value;
    },
    get columnFilters() {
      return columnFilters.value;
    },
    get columnVisibility() {
      return columnVisibility.value;
    },
    get rowSelection() {
      return rowSelection.value;
    }
  }
});

// The rows are one server page already, so the page lives in this object and the table does not slice.
const paging = props.pageData ?? reactive<PaginationState>({ pageIndex: 1, pageSize: Math.max(props.data.length, 1) });

const allColumns = computed(() => {
  return table.getAllColumns().filter((column) => {
    return typeof column.accessorFn !== "undefined" && column.getCanHide();
  });
});

function getColumnSettingLocal() {
  if (props.saveColumnVisible && props.saveColumnVisible.isRemeber) {
    const resLocal = localStorage.getItem(LOCAL_STORAGE_KEY.VISIBLE_COLUMN);
    const parseData = resLocal ? JSON.parse(resLocal) : null;
    if (parseData) {
      const savedColumns = parseData[props.saveColumnVisible.name];

      if (savedColumns) {
        const visibilityState = allColumns.value.reduce(
          (acc: any, column: any) => {
            acc[column.id] = savedColumns.includes(column.id);
            return acc;
          },
          {}
        );

        columnVisibility.value = visibilityState;
        table.setColumnVisibility(visibilityState);
        return;
      }
    }
  } else {
    const defaultVisibilityState = allColumns.value.reduce(
      (acc: any, column: any) => {
        acc[column.id] = true;
        return acc;
      },
      {}
    );

    columnVisibility.value = defaultVisibilityState;
    table.setColumnVisibility(defaultVisibilityState);
  }
}
onMounted(async () => {
  getColumnSettingLocal();
});

watchEffect(() => {
  if (props.saveColumnVisible && props.saveColumnVisible.isRemeber) {
    if (Object.keys(columnVisibility.value).length > 0) {
      table.setColumnVisibility(columnVisibility.value);
    }
  }
});
</script>
