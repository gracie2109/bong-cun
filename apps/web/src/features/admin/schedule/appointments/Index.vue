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
          <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
          <Button v-if="canCreate" :disabled="!branchId" @click="openNew">
            <Plus class="mr-2 size-4" />
            {{ $t("spa.appointments.new") }}
          </Button>
        </div>
      </div>

      <SearchView
        v-model:search="search"
        :placeholder="$t('spa.appointments.searchPlaceholder')"
        :active-count="activeCount"
        :refreshing="listQuery.isFetching.value"
        @open-filters="syncDraft"
        @apply="apply"
        @reset-filters="resetDraft"
        @clear="clearAll"
        @refresh="listQuery.refetch()"
      >
        <template #filters><AppointmentFilterFields v-model:from="draft.from" v-model:to="draft.to" v-model:status="draft.status" /></template>
        <template #actions><ExportMenu :exporter="exporter" compact /></template>
      </SearchView>

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
            <TableStateRows :filtered="isFiltered" @clear="clearAll" :colspan="5" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('spa.appointments.empty')" />
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
import { ListChecks, Plus } from "lucide-vue-next";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import { SearchView } from "@/components/common/search-view";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { usePagedList } from "@/composables/usePagedList";
import { useAppointmentsList } from "@/features/admin/schedule/queries/spa";
import { isEditable, type Appointment } from "@bongcun/supabase/spa";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/features/admin/components";
import { BranchPicker } from "@/features/admin/pos";
import SpaNav from "../SpaNav.vue";
import AppointmentDetailDialog from "./AppointmentDetailDialog.vue";
import AppointmentDialog from "./AppointmentDialog.vue";
import AppointmentFilterFields from "./AppointmentFilterFields.vue";
import AppointmentRow from "./AppointmentRow.vue";
import { useAppointmentFilters } from "./useAppointmentFilters";
import { useAppointmentsExport } from "./useAppointmentsExport";

const auth = useAuthStore();
const canCreate = computed(() => auth.can("schedule", "CREATE"));
const canUpdate = computed(() => auth.can("schedule", "UPDATE"));
const { branches, branch, branchId, selectBranch } = useCurrentBranch();

const { search, page, filter, draft, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft } = useAppointmentFilters(branchId);
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
