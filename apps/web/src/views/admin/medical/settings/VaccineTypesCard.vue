<template>
  <section class="flex min-h-0 flex-1 flex-col gap-4">
    <SearchView
      v-model:search="search"
      :placeholder="$t('medical.vaccines.searchPlaceholder')"
      :active-count="activeCount"
      :refreshing="listQuery.isFetching.value"
      @open-filters="syncDraft"
      @apply="apply"
      @reset-filters="resetDraft"
      @clear="clearAll"
      @refresh="listQuery.refetch()"
    >
      <template #filters>
        <FilterField :label="$t('medical.vaccines.kind')">
          <Select v-model="draft.kind">
            <SelectTrigger :aria-label="$t('medical.vaccines.kind')"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem :value="FILTER_ALL">{{ $t("petCare.common.all") }}</SelectItem>
              <SelectItem v-for="kind in VACCINE_KINDS" :key="kind" :value="kind">{{ $t(`medical.vaccines.kinds.${kind}`) }}</SelectItem>
            </SelectContent>
          </Select>
        </FilterField>
      </template>
      <template #actions>
        <Button v-if="canEdit" size="sm" @click="openNew">
          <Plus class="mr-1 size-4" />
          {{ $t("medical.vaccines.add") }}
        </Button>
      </template>
    </SearchView>

    <PagedTableCard class="min-h-0 flex-1" v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total" :loading="listQuery.isFetching.value">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="px-4 py-3 font-semibold">{{ $t("medical.vaccines.name") }}</th>
            <th class="px-4 py-3 font-semibold">{{ $t("medical.vaccines.species") }}</th>
            <th class="px-4 py-3 font-semibold">{{ $t("medical.vaccines.protocol") }}</th>
            <th class="px-4 py-3 font-semibold">{{ $t("medical.vaccines.product") }}</th>
            <th class="px-4 py-3" />
          </tr>
        </thead>
        <tbody>
          <TableStateRows :filtered="isFiltered" :colspan="5" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('medical.vaccines.empty')" @clear="clearAll" />
          <VaccineTypeRow v-for="row in rows" :key="row.id" :type="row" :can-edit="canEdit" @edit="openEdit(row)" />
        </tbody>
      </table>
    </PagedTableCard>

    <VaccineTypeDialog v-model:open="dialogOpen" :type="editing" />
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
import { useVaccineTypes } from "@/queries/medical";
import { VACCINE_KINDS, type VaccineKind, type VaccineType, type VaccineTypeFilter } from "@bongcun/core/medical";
import VaccineTypeDialog from "./VaccineTypeDialog.vue";
import VaccineTypeRow from "./VaccineTypeRow.vue";

const props = defineProps<{ branchId: string | undefined; canEdit: boolean }>();
const branchId = computed(() => props.branchId);

const { search, debouncedSearch, page, applied, draft, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft } = useListFilters({
  pageSize: 20,
  defaults: { kind: FILTER_ALL as string },
});
const filter = computed<VaccineTypeFilter>(() => ({
  search: debouncedSearch.value,
  kind: applied.value.kind === FILTER_ALL ? undefined : (applied.value.kind as VaccineKind),
}));
const listQuery = useVaccineTypes(branchId, page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);

const dialogOpen = ref(false);
const editing = ref<VaccineType | null>(null);

const openNew = () => {
  editing.value = null;
  dialogOpen.value = true;
};

const openEdit = (row: VaccineType) => {
  editing.value = row;
  dialogOpen.value = true;
};
</script>
