<template>
  <section class="flex min-h-0 flex-1 flex-col gap-4">
    <SearchView
      v-model:search="search"
      :placeholder="$t('boarding.kennels.searchPlaceholder')"
      :active-count="activeCount"
      :refreshing="listQuery.isFetching.value"
      @open-filters="syncDraft"
      @apply="apply"
      @reset-filters="resetDraft"
      @clear="clearAll"
      @refresh="listQuery.refetch()"
    >
      <template #filters>
        <FilterField :label="$t('boarding.kennels.type')">
          <Select v-model="draft.typeId">
            <SelectTrigger :aria-label="$t('boarding.kennels.type')"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
              <SelectItem v-for="item in types" :key="item.id" :value="item.id">{{ item.name }}</SelectItem>
            </SelectContent>
          </Select>
        </FilterField>
      </template>
      <template #actions>
        <Button v-if="canEdit" size="sm" :disabled="!types.length" @click="openNew">
          <Plus class="mr-1 size-4" />
          {{ $t("boarding.kennels.add") }}
        </Button>
      </template>
    </SearchView>

    <PagedTableCard class="min-h-0 flex-1" v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total" :loading="listQuery.isFetching.value">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="px-4 py-3 font-semibold">{{ $t("boarding.kennels.code") }}</th>
            <th class="px-4 py-3 font-semibold">{{ $t("boarding.kennels.type") }}</th>
            <th class="px-4 py-3 font-semibold">{{ $t("boarding.kennels.status") }}</th>
            <th class="px-4 py-3" />
          </tr>
        </thead>
        <tbody>
          <TableStateRows :filtered="isFiltered" :colspan="4" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('boarding.kennels.empty')" @clear="clearAll" />
          <KennelRow v-for="row in rows" :key="row.id" :kennel="row" :can-edit="canEdit" :can-update="canUpdate" @edit="openEdit(row)" @status="(status) => statusMutation.mutate({ id: row.id, status })" />
        </tbody>
      </table>
    </PagedTableCard>

    <KennelDialog v-model:open="dialogOpen" :branch-id="branchId" :kennel="editing" :types="types" />
  </section>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Plus } from "lucide-vue-next";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import { FilterField, SearchView } from "@/components/common/search-view";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useListFilters } from "@/composables/useListFilters";
import { usePagedList } from "@/composables/usePagedList";
import { FILTER_ALL } from "@/lib/listing";
import { useKennels, useSetKennelStatus } from "@/features/admin/boarding/queries";
import type { Kennel, KennelFilter } from "@bongcun/core/boarding";
import KennelDialog from "./KennelDialog.vue";
import KennelRow from "./KennelRow.vue";
import { useKennelTypeOptions } from "../useKennelTypeOptions";

const props = defineProps<{ branchId: string | undefined; canEdit: boolean; canUpdate: boolean }>();
const branchId = computed(() => props.branchId);

const { search, debouncedSearch, page, applied, draft, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft } = useListFilters({
  pageSize: 20,
  defaults: { typeId: FILTER_ALL as string },
  resetOn: [branchId],
});
const filter = computed<KennelFilter>(() => ({
  search: debouncedSearch.value,
  typeId: applied.value.typeId === FILTER_ALL ? undefined : applied.value.typeId,
}));
const listQuery = useKennels(branchId, page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);
const types = useKennelTypeOptions(branchId);
const statusMutation = useSetKennelStatus();

const dialogOpen = ref(false);
const editing = ref<Kennel | null>(null);

const openNew = () => {
  editing.value = null;
  dialogOpen.value = true;
};

const openEdit = (row: Kennel) => {
  editing.value = row;
  dialogOpen.value = true;
};
</script>
