<template>
  <section class="flex min-h-0 flex-1 flex-col gap-4">
    <SearchView
      v-model:search="search"
      :placeholder="$t('boarding.types.searchPlaceholder')"
      :active-count="activeCount"
      :refreshing="listQuery.isFetching.value"
      @apply="apply"
      @clear="clearAll"
      @refresh="listQuery.refetch()"
    >
      <template #actions>
        <Button v-if="canEdit" size="sm" @click="openNew">
          <Plus class="mr-1 size-4" />
          {{ $t("boarding.types.add") }}
        </Button>
      </template>
    </SearchView>

    <PagedTableCard class="min-h-0 flex-1" v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total" :loading="listQuery.isFetching.value">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="px-4 py-3 font-semibold">{{ $t("boarding.types.name") }}</th>
            <th class="px-4 py-3 font-semibold">{{ $t("boarding.types.species") }}</th>
            <th class="px-4 py-3 font-semibold">{{ $t("boarding.types.capacity") }}</th>
            <th class="px-4 py-3 font-semibold">{{ $t("boarding.types.nightPrice") }}</th>
            <th class="px-4 py-3 text-center font-semibold">{{ $t("boarding.types.kennels") }}</th>
            <th class="px-4 py-3" />
          </tr>
        </thead>
        <tbody>
          <TableStateRows :filtered="isFiltered" :colspan="6" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('boarding.types.empty')" @clear="clearAll" />
          <KennelTypeRow v-for="row in rows" :key="row.id" :type="row" :can-edit="canEdit" @edit="openEdit(row)" />
        </tbody>
      </table>
    </PagedTableCard>

    <KennelTypeDialog v-model:open="dialogOpen" :type="editing" :branches="branches" />
  </section>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Plus } from "lucide-vue-next";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import { SearchView } from "@/components/common/search-view";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { usePagedList } from "@/composables/usePagedList";
import { useListFilters } from "@/composables/useListFilters";
import { useKennelTypes } from "@/queries/boarding";
import type { Branch } from "@bongcun/supabase/users";
import type { KennelType, KennelTypeFilter } from "@bongcun/core/boarding";
import KennelTypeDialog from "./KennelTypeDialog.vue";
import KennelTypeRow from "./KennelTypeRow.vue";

const props = defineProps<{ branchId: string | undefined; branches: Branch[]; canEdit: boolean }>();
const branchId = computed(() => props.branchId);

const { search, debouncedSearch, page, activeCount, isFiltered, apply, clearAll } = useListFilters({
  pageSize: 20,
  defaults: {},
  resetOn: [branchId],
});
const filter = computed<KennelTypeFilter>(() => ({ search: debouncedSearch.value }));
const listQuery = useKennelTypes(branchId, page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);

const dialogOpen = ref(false);
const editing = ref<KennelType | null>(null);

const openNew = () => {
  editing.value = null;
  dialogOpen.value = true;
};

const openEdit = (row: KennelType) => {
  editing.value = row;
  dialogOpen.value = true;
};
</script>
