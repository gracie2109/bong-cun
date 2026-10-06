<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <User2 class="size-4 text-primary" />
      {{ $t("pageMeta.customers") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="p-5 bg-white min-h-dvh relative top-10">
          <DataTable
            :headerAdvanced="headerAdvanced"
            :data="users"
            :columns="columns"
            :page-count="pageCount"
            :page-data="pageData"
            :saveColumnVisible="{
              name: 'customers',
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
          >
          </DataTable>
  
      <Dialog :open="open" @update:open="handleRese">
        <DialogContent>
          <InfomationForm
            :form="form"
            :loading="loading"
            :list-user-group="[]"
            :addressModel="addressModel"
            @on-submit="submitHdl"
          />
        </DialogContent>
      </Dialog>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { Header, ContentWrap } from "@/views/admin/components";
import { User2 } from "lucide-vue-next";
import InfomationForm from "./components/InfomationForm.vue";
import { useForm } from "vee-validate";
import { computed, ref } from "vue";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import type { IUser } from "@/types/user.type";
import { initAddress, type IAddress } from "@/types/location.type";
import { useCreateUser, useUsersList } from "@/queries/users";
import usePagedRows from "@/composables/usePagedRows";
import type { ColumnDef, PaginationState } from "@tanstack/vue-table";
import { HEADER_ADVANCE_FUNCTION, INITIAL_PAGE_INDEX } from "@/lib/constants";
import { reactive } from "vue";
import type { IHeaderAdvanced } from "@/types";
import DataTableColumnHeader from "@/components/common/DataTable/DataTableColumnHeader.vue";
import { h } from "vue";
import { formatDateTime } from "@/lib/utils";
import { DataTable } from "@/components/common";

const addressModel = ref<IAddress>({ ...initAddress });

const form = useForm<IUser>({
  initialValues: {
    province: initAddress,
    password: "",
    fullName: "",
    phoneNumber: "",
    photoURL: "",
    email: "",
    displayName: "",
    groupIds: null,
  },
});
const pageData = ref<PaginationState>({
  pageIndex: INITIAL_PAGE_INDEX,
  pageSize: 5,
});

// This screen is "Customers"; the old query selected users without a role.
const usersQuery = useUsersList(pageData, "customer");
const { rows: users, total: pageCount } = usePagedRows(usersQuery, pageData);
const createUser = useCreateUser();
const loading = computed(() => createUser.isPending.value);
const open = ref(false);

const headerAdvanced = reactive<IHeaderAdvanced[]>([
  HEADER_ADVANCE_FUNCTION.ADD_NEW,
  HEADER_ADVANCE_FUNCTION.SETTING_COLUMN,
  HEADER_ADVANCE_FUNCTION.IMPORT,

]);

function onReset() {
  alert("reset");
}
function clearFilter() {
  alert("clearFilter");
}
function setOpen() {
  open.value = !open.value;
}

function loadDataForPage(page: number) {
  pageData.value.pageIndex = page;
}
function updatePageSize(newPs: number) {
  pageData.value.pageSize = +newPs;
  pageData.value.pageIndex = INITIAL_PAGE_INDEX;
}

const handleRese = () => {
  form.resetForm();
  open.value = !open.value;
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
  handleRese();
});

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
    accessorKey: "email",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "Email" }),
    cell: ({ row }) => {
      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("email")
      );
    },
  },
  {
    accessorKey: "displayName",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "Display name" }),
    cell: ({ row }) => {
      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("displayName")
      );
    },
  },
  {
    accessorKey: "fullName",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "Full name" }),
    cell: ({ row }) => {
      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("fullName")
      );
    },
  },
  {
    accessorKey: "gender",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "Gender" }),
    cell: ({ row }) => {
      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("gender")
      );
    },
  },
  {
    accessorKey: "groupIds",
    header: ({ column }) => h(DataTableColumnHeader, { column, title: "Groups" }),
    cell: ({ row }) => {
      return h(
        "span",
        { class: "max-w-[500px] truncate font-medium" },
        row.getValue("groupIds")
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
  // {
  //   id: "function",
  //   accessorKey: "function",
  //   header: ({ column }) =>
  //     h(DataTableColumnHeader, { column, title: "Function" }),
  //   cell: ({ row }) =>
  //     h(RowFunction, {
  //       row,
  //       onClick: (item: any) => {
  //         handleActionRow(item);
  //       },
  //     }),
  // },
]);
</script>
