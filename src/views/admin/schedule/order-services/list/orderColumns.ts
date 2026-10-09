import { h, type Ref } from "vue";
import type { ColumnDef, Row } from "@tanstack/vue-table";
import DataTableColumnHeader from "@/components/common/DataTable/DataTableColumnHeader.vue";
import { status } from "@/data/order-services-status.json";
import { formatDateTime } from "@/lib/utils";
import RowAction from "./components/RowAction.vue";

const CELL_CLASS = "max-w-[500px] truncate font-medium";
const SERVICES_SEPARATOR = " + ";

const sortableHeader = (title: string) => ({ column }: { column: any }) =>
  h(DataTableColumnHeader, { column, title });

/** A column that shows one field as a plain, truncated text. */
const textColumn = (
  key: string,
  title: string,
  format: (value: unknown, row: Row<any>) => string | undefined = (value) => value as string
): ColumnDef<any> => ({
  accessorKey: key,
  header: sortableHeader(title),
  cell: ({ row }) => h("span", { class: CELL_CLASS }, format(row.getValue(key), row)),
});

/** Columns of the schedule list; `locale` picks the language of the status names. */
export const buildOrderColumns = (locale: Ref<string>): ColumnDef<any>[] => [
  textColumn("index", "#"),
  textColumn("name", "Username"),
  textColumn("phoneNumber", "Phone Number"),
  textColumn("petNum", "Pet Number"),
  textColumn("time", "Time", (value) => formatDateTime(value as string)),
  textColumn("services", "Services", (value) =>
    (value as { name?: string }[] | undefined)?.map((service) => service?.name).join(SERVICES_SEPARATOR)
  ),
  textColumn("status", "Status", (value) => {
    const entry = status.find((item) => item.value === value) as { name?: Record<string, string> } | undefined;
    return entry?.name?.[String(locale.value)];
  }),
  {
    id: "function",
    accessorKey: "function",
    header: sortableHeader("Function"),
    cell: ({ row }) => h(RowAction, { row }),
  },
];
