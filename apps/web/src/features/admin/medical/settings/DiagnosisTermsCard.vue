<template>
  <section class="flex min-h-0 flex-1 flex-col gap-4">
    <SearchView
      v-model:search="search"
      :placeholder="$t('medical.diagnoses.searchPlaceholder')"
      :active-count="activeCount"
      :refreshing="listQuery.isFetching.value"
      @apply="apply"
      @clear="clearAll"
      @refresh="listQuery.refetch()"
    >
      <template #actions>
        <Button v-if="canEdit" size="sm" @click="openNew">
          <Plus class="mr-1 size-4" />
          {{ $t("medical.diagnoses.add") }}
        </Button>
      </template>
    </SearchView>

    <PagedTableCard class="min-h-0 flex-1" v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total" :loading="listQuery.isFetching.value">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="px-4 py-3 font-semibold">{{ $t("medical.diagnoses.name") }}</th>
            <th class="px-4 py-3 font-semibold">{{ $t("medical.diagnoses.species") }}</th>
            <th class="px-4 py-3" />
          </tr>
        </thead>
        <tbody>
          <TableStateRows :filtered="isFiltered" :colspan="3" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('medical.diagnoses.empty')" @clear="clearAll" />
          <DiagnosisTermRow v-for="row in rows" :key="row.id" :term="row" :can-edit="canEdit" @edit="openEdit(row)" />
        </tbody>
      </table>
    </PagedTableCard>

    <DiagnosisTermDialog v-model:open="dialogOpen" :term="editing" />
  </section>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Plus } from "lucide-vue-next";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import { SearchView } from "@/components/common/search-view";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { useListFilters } from "@/composables/useListFilters";
import { usePagedList } from "@/composables/usePagedList";
import { useDiagnosisTerms } from "@/queries/medical";
import type { DiagnosisTerm, DiagnosisTermFilter } from "@bongcun/core/medical";
import DiagnosisTermDialog from "./DiagnosisTermDialog.vue";
import DiagnosisTermRow from "./DiagnosisTermRow.vue";

defineProps<{ canEdit: boolean }>();

const { search, debouncedSearch, page, activeCount, isFiltered, apply, clearAll } = useListFilters({
  pageSize: 20,
  defaults: {},
});
const filter = computed<DiagnosisTermFilter>(() => ({ search: debouncedSearch.value }));
const listQuery = useDiagnosisTerms(page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);

const dialogOpen = ref(false);
const editing = ref<DiagnosisTerm | null>(null);

const openNew = () => {
  editing.value = null;
  dialogOpen.value = true;
};

const openEdit = (row: DiagnosisTerm) => {
  editing.value = row;
  dialogOpen.value = true;
};
</script>
