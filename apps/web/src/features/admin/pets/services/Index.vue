<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <Scissors class="size-4 text-primary" />
      {{ $t("petCare.services.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-2xl font-bold">
            {{ $t("petCare.services.title") }}
            <span class="text-muted-foreground">({{ total }})</span>
          </h2>
          <p class="text-sm text-muted-foreground">{{ $t("petCare.services.subtitle") }}</p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <Button v-if="canCreate" @click="openCreate">
            <Plus class="mr-2 size-4" />
            {{ $t("petCare.services.add") }}
          </Button>
        </div>
      </div>

      <PetsNav />

      <SearchView
        v-model:search="search"
        :placeholder="$t('petCare.services.searchPlaceholder')"
        :active-count="activeCount"
        :refreshing="servicesQuery.isFetching.value"
        @open-filters="syncDraft"
        @apply="apply"
        @reset-filters="resetDraft"
        @clear="clearAll"
        @refresh="servicesQuery.refetch()"
      >
        <template #filters>
          <ServicesFilterFields
            v-model:species-id="draft.speciesId"
            v-model:type="draft.type"
            v-model:category="draft.category"
            v-model:show-archived="draft.showArchived"
            :species="species"
          />
        </template>
        <template #actions><ExportMenu :exporter="exporter" compact /></template>
      </SearchView>

      <PagedTableCard class="min-h-0 flex-1" v-model:page="pageData.pageIndex" v-model:page-size="pageData.pageSize" :page-count="pageCount" :loading="servicesQuery.isFetching.value" :count="services.length" :total="total">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.services.col.service") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.services.col.category") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.services.col.species") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.services.col.pricing") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.services.col.duration") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("petCare.services.col.actions") }}</th>
            </tr>
          </thead>
          <tbody>
            <TableStateRows :filtered="isFiltered" @clear="clearAll" :colspan="6" :pending="servicesQuery.isPending.value" :empty="services.length === 0" :empty-text="$t('petCare.services.empty')" skeleton-class="h-10 w-full" />
            <ServiceRow
              v-for="service in services"
              :key="service.id"
              :service="service"
              :can-update="canUpdate"
              @edit="openEdit"
              @archive="toArchive = $event"
              @restore="setActive($event, true)"
            />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <ServiceFormSheet v-model:open="formOpen" :service="editing" />

    <ConfirmDialog
      :open="!!toArchive"
      :title="$t('petCare.common.confirmArchiveTitle', { name: toArchive?.name ?? '' })"
      :desc="$t('petCare.common.confirmArchiveDesc')"
      :ok-btn="$t('petCare.common.confirm')"
      @cancel="toArchive = null"
      @open-change="toArchive = null"
      @handle-ok="archive"
    />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { Plus, Scissors } from "lucide-vue-next";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { SearchView } from "@/components/common/search-view";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import { Button } from "@/components/ui/button";
import { usePagedList } from "@/composables/usePagedList";
import { usePermission } from "@/composables/usePermission";
import { usePetServicesList, useSetPetServiceActive } from "@/queries/petServices";
import type { PetService } from "@bongcun/supabase/spa";
import { ContentWrap, Header } from "@/features/admin/components";
import PetsNav from "../PetsNav.vue";
import ServiceFormSheet from "./ServiceFormSheet.vue";
import ServiceRow from "./ServiceRow.vue";
import ServicesFilterFields from "./ServicesFilterFields.vue";
import { useServicesExport } from "./useServicesExport";
import { useServicesFilters } from "./useServicesFilters";

const { search, pageData, filter, species, draft, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft } = useServicesFilters();

const exporter = useServicesExport(filter);
const formOpen = ref(false);
const editing = ref<PetService | null>(null);
const toArchive = ref<PetService | null>(null);

const servicesQuery = usePetServicesList(pageData, filter);
const { canCreate, canUpdate } = usePermission("petServices");
const { rows: services, total, pageCount } = usePagedList(servicesQuery, pageData);

const setActiveMutation = useSetPetServiceActive();

const openCreate = () => {
  editing.value = null;
  formOpen.value = true;
};

const openEdit = (service: PetService) => {
  editing.value = service;
  formOpen.value = true;
};

const setActive = async (service: PetService, isActive: boolean) => {
  try {
    await setActiveMutation.mutateAsync({ id: service.id, isActive });
  } catch {
    // the mutation already showed the failure toast
  }
};

const archive = async () => {
  const service = toArchive.value;
  toArchive.value = null;
  if (service) await setActive(service, false);
};
</script>
