<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ListChecks class="size-4 text-primary" />
      {{ $t("spa.appointments.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <SpaNav />
        <div class="flex flex-wrap items-center gap-2">
          <ExportMenu :exporter="exporter" />
          <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
          <Button v-if="canCreate" :disabled="!branchId" @click="openNew">
            <Plus class="mr-2 size-4" />
            {{ $t("spa.appointments.new") }}
          </Button>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('spa.appointments.searchPlaceholder')" />
        </div>
        <label class="flex items-center gap-2 text-xs text-muted-foreground">
          {{ $t("spa.appointments.from") }}
          <Input v-model="from" type="date" class="h-9 w-40 bg-white" />
        </label>
        <label class="flex items-center gap-2 text-xs text-muted-foreground">
          {{ $t("spa.appointments.to") }}
          <Input v-model="to" type="date" class="h-9 w-40 bg-white" />
        </label>
        <Select v-model="status">
          <SelectTrigger class="w-44" :aria-label="$t('spa.appointments.status')"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
            <SelectItem v-for="item in APPOINTMENT_STATUSES" :key="item" :value="item">{{ $t(`spa.status.${item}`) }}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <PagedTableCard class="min-h-0 flex-1" v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total" :loading="listQuery.isFetching.value">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("spa.appointments.code") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("spa.appointments.time") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("spa.appointments.customer") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("spa.appointments.tickets") }}</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            <TableStateRows :colspan="5" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('spa.appointments.empty')" />
            <AppointmentRow v-for="row in rows" :key="row.id" :appointment="row" :can-edit="canEditRow(row)" @edit="openEdit(row)" @open="openDetail(row)" />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <AppointmentDetailDialog v-model:open="detailOpen" :appointment="detailing" @edit="editFromDetail" />
    <AppointmentDialog v-if="branchId" v-model:open="dialogOpen" :branch-id="branchId" :appointment="editing" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { ListChecks, Plus, Search } from "lucide-vue-next";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { usePagedList } from "@/composables/usePagedList";
import { FILTER_ALL } from "@/lib/listing";
import { useAppointmentsList } from "@/queries/spa";
import { APPOINTMENT_STATUSES, isEditable, type Appointment } from "@/repositories/spa";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "@/views/admin/pos/components/BranchPicker.vue";
import SpaNav from "../SpaNav.vue";
import AppointmentDetailDialog from "./AppointmentDetailDialog.vue";
import AppointmentDialog from "./AppointmentDialog.vue";
import AppointmentRow from "./AppointmentRow.vue";
import { useAppointmentFilters } from "./useAppointmentFilters";
import { useAppointmentsExport } from "./useAppointmentsExport";

const auth = useAuthStore();
const canCreate = computed(() => auth.can("schedule", "CREATE"));
const canUpdate = computed(() => auth.can("schedule", "UPDATE"));
const { branches, branch, branchId, selectBranch } = useCurrentBranch();

const { search, from, to, status, page, filter } = useAppointmentFilters(branchId);
const exporter = useAppointmentsExport(branchId, filter, () => branch.value?.name);
const listQuery = useAppointmentsList(branchId, page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);

const dialogOpen = ref(false);
const editing = ref<Appointment | null>(null);

const canEditRow = (row: Appointment) => canUpdate.value && isEditable(row.status);

const openNew = () => {
  editing.value = null;
  dialogOpen.value = true;
};

const detailOpen = ref(false);
const detailing = ref<Appointment | null>(null);

const openDetail = (row: Appointment) => {
  detailing.value = row;
  detailOpen.value = true;
};

const editFromDetail = (row: Appointment) => {
  detailOpen.value = false;
  openEdit(row);
};

const openEdit = (row: Appointment) => {
  editing.value = row;
  dialogOpen.value = true;
};
</script>
