<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <PawPrint class="size-4 text-primary" />
      {{ $t("petCare.pets.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-2xl font-bold">
            {{ $t("petCare.pets.title") }}
            <span class="text-muted-foreground">({{ total }})</span>
          </h2>
          <p class="text-sm text-muted-foreground">{{ $t("petCare.pets.subtitle") }}</p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <Button v-if="canCreate" @click="registerOpen = true">
            <Plus class="mr-2 size-4" />
            {{ $t("petCare.pets.register") }}
          </Button>
        </div>
      </div>

      <PetsNav />

      <SearchView
        v-model:search="search"
        :placeholder="$t('petCare.pets.searchPlaceholder')"
        :active-count="activeCount"
        :refreshing="petsQuery.isFetching.value"
        @open-filters="syncDraft"
        @apply="apply"
        @reset-filters="resetDraft"
        @clear="clearAll"
        @refresh="petsQuery.refetch()"
      >
        <template #filters>
          <PetsFilterFields
            v-model:species-id="draft.speciesId"
            v-model:bracket-id="draft.bracketId"
            v-model:status="draft.status"
            :species="species"
            :brackets="brackets"
          />
        </template>
        <template #actions>
          <ExportMenu :exporter="exporter" compact />
          <ImportButton :allowed="canImport" compact @click="importOpen = true" />
        </template>
      </SearchView>

      <PagedTableCard class="min-h-0 flex-1" v-model:page="pageData.pageIndex" v-model:page-size="pageData.pageSize" :page-count="pageCount" :loading="petsQuery.isFetching.value" :count="pets.length" :total="total">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.pets.col.pet") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.pets.col.age") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.pets.col.weight") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.pets.col.owner") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("petCare.pets.col.actions") }}</th>
            </tr>
          </thead>
          <tbody>
            <TableStateRows :filtered="isFiltered" @clear="clearAll" :colspan="5" :pending="petsQuery.isPending.value" :empty="pets.length === 0" :empty-text="$t('petCare.pets.empty')" skeleton-class="h-10 w-full" />
            <PetRow
              v-for="pet in pets"
              :key="pet.id"
              :pet="pet"
              :can-update="canUpdate"
              @open="openPet"
              @archive="toArchive = $event"
              @restore="changeStatus($event, 'active')"
            />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <RegisterPetSheet v-model:open="registerOpen" @registered="openPet" />
    <PetsImportDialog v-if="canImport" v-model:open="importOpen" />

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
import { computed, ref } from "vue";
import { useRouter } from "vue-router";
import { PawPrint, Plus } from "lucide-vue-next";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import ImportButton from "@/components/common/data-io/ImportButton.vue";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { SearchView } from "@/components/common/search-view";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import { Button } from "@/components/ui/button";
import { usePagedList } from "@/composables/usePagedList";
import { usePermission } from "@/composables/usePermission";
import { useAuthStore } from "@/stores";
import { usePetsList, useSetPetStatus } from "@/queries/pets";
import type { PetListItem, PetStatus } from "@/repositories/pets";
import { ContentWrap, Header } from "@/views/admin/components";
import PetsImportDialog from "./import/PetsImportDialog.vue";
import PetRow from "./components/PetRow.vue";
import PetsFilterFields from "./components/PetsFilterFields.vue";
import RegisterPetSheet from "./components/RegisterPetSheet.vue";
import PetsNav from "./PetsNav.vue";
import { usePetsExport } from "./usePetsExport";
import { usePetsFilters } from "./usePetsFilters";

const router = useRouter();
const { canCreate, canUpdate } = usePermission("pets");

const { search, pageData, filter, species, brackets, draft, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft } =
  usePetsFilters();

const exporter = usePetsExport(filter);
const canImport = computed(() => useAuthStore().can("pets", "IMPORT"));
const importOpen = ref(false);
const registerOpen = ref(false);
const toArchive = ref<PetListItem | null>(null);

const petsQuery = usePetsList(pageData, filter);
const { rows: pets, total, pageCount } = usePagedList(petsQuery, pageData);

const setStatus = useSetPetStatus();

const openPet = (petId: string) => router.push({ name: "petDetail", params: { petId } });

const changeStatus = async (id: string, status: PetStatus) => {
  try {
    await setStatus.mutateAsync({ id, status });
  } catch {
    // the mutation already showed the failure toast
  }
};

const archive = async () => {
  const pet = toArchive.value;
  toArchive.value = null;
  if (pet) await changeStatus(pet.id, "archived");
};
</script>
