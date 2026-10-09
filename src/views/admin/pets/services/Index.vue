<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <Scissors class="size-4 text-primary" />
      {{ $t("petCare.services.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-2xl font-bold">
            {{ $t("petCare.services.title") }}
            <span class="text-muted-foreground">({{ total }})</span>
          </h2>
          <p class="text-sm text-muted-foreground">{{ $t("petCare.services.subtitle") }}</p>
        </div>
        <Button v-if="canCreate" @click="openCreate">
          <Plus class="mr-2 size-4" />
          {{ $t("petCare.services.add") }}
        </Button>
      </div>

      <PetsNav />

      <ServicesFilterBar
        v-model:search="search"
        v-model:species-filter="speciesFilter"
        v-model:type-filter="typeFilter"
        v-model:show-archived="showArchived"
        :species="species"
      />

      <PagedTableCard v-model:page="pageData.pageIndex" :page-count="pageCount" :loading="servicesQuery.isFetching.value" :count="services.length" :total="total">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.services.col.service") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.services.col.species") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.services.col.pricing") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.services.col.duration") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("petCare.services.col.actions") }}</th>
            </tr>
          </thead>
          <tbody>
            <TableStateRows :colspan="5" :pending="servicesQuery.isPending.value" :empty="services.length === 0" :empty-text="$t('petCare.services.empty')" skeleton-class="h-10 w-full" />
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
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import { Button } from "@/components/ui/button";
import { usePagedList } from "@/composables/usePagedList";
import { usePermission } from "@/composables/usePermission";
import { usePetServicesList, useSetPetServiceActive } from "@/queries/petServices";
import type { PetService } from "@/repositories/petServices";
import { ContentWrap, Header } from "@/views/admin/components";
import PetsNav from "../PetsNav.vue";
import ServiceFormSheet from "./ServiceFormSheet.vue";
import ServiceRow from "./ServiceRow.vue";
import ServicesFilterBar from "./ServicesFilterBar.vue";
import { useServicesFilters } from "./useServicesFilters";

const { search, speciesFilter, typeFilter, showArchived, pageData, filter, species } = useServicesFilters();

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
