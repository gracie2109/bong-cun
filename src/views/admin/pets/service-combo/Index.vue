<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <Layers2 class="size-4 text-primary" />
      {{ $t("petCare.combos.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-2xl font-bold">
            {{ $t("petCare.combos.title") }}
            <span class="text-muted-foreground">({{ total }})</span>
          </h2>
          <p class="text-sm text-muted-foreground">{{ $t("petCare.combos.subtitle") }}</p>
        </div>
        <Button v-if="canCreate" @click="openCreate">
          <Plus class="mr-2 size-4" />
          {{ $t("petCare.combos.add") }}
        </Button>
      </div>

      <PetsNav />

      <div class="flex items-center justify-between gap-3 rounded-xl border bg-white p-3">
        <label class="flex items-center gap-2 text-sm text-muted-foreground">
          <Switch v-model="showArchived" />
          {{ $t("petCare.combos.showArchived") }}
        </label>
        <TablePager v-model:page="pageData.pageIndex" :page-count="pageCount" :loading="combosQuery.isFetching.value" />
      </div>

      <div class="table-scroll admin-table rounded-xl border bg-white">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.combos.title") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.services.col.species") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.services.title") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.services.col.price") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("petCare.common.status") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("petCare.services.col.actions") }}</th>
            </tr>
          </thead>
          <tbody>
            <TableStateRows :colspan="6" :pending="combosQuery.isPending.value" :empty="combos.length === 0" :empty-text="$t('petCare.combos.empty')" :skeleton-rows="4" skeleton-class="h-10 w-full" />
            <ComboRow
              v-for="combo in combos"
              :key="combo.id"
              :combo="combo"
              :can-update="canUpdate"
              @edit="openEdit"
              @archive="toArchive = $event"
              @restore="setActive($event, true)"
            />
          </tbody>
        </table>
      </div>
    </div>

    <ComboFormSheet v-model:open="formOpen" :combo="editing" />

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
import { reactive, ref, watch } from "vue";
import { Layers2, Plus } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import TablePager from "@/components/common/TablePager.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { usePagedList } from "@/composables/usePagedList";
import { usePermission } from "@/composables/usePermission";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { usePetCombosList, useSetPetComboActive } from "@/queries/petCombos";
import type { PetCombo } from "@/repositories/petCombos";
import { ContentWrap, Header } from "@/views/admin/components";
import PetsNav from "../PetsNav.vue";
import ComboFormSheet from "./ComboFormSheet.vue";
import ComboRow from "./ComboRow.vue";

const PAGE_SIZE = 10;

const pageData = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize: PAGE_SIZE });
const showArchived = ref(false);
const formOpen = ref(false);
const editing = ref<PetCombo | null>(null);
const toArchive = ref<PetCombo | null>(null);

const combosQuery = usePetCombosList(pageData, showArchived);
const { canCreate, canUpdate } = usePermission("petServices");
const { rows: combos, total, pageCount } = usePagedList(combosQuery, pageData);
const setActiveMutation = useSetPetComboActive();

watch(showArchived, () => {
  pageData.pageIndex = INITIAL_PAGE_INDEX;
});

const openCreate = () => {
  editing.value = null;
  formOpen.value = true;
};

const openEdit = (combo: PetCombo) => {
  editing.value = combo;
  formOpen.value = true;
};

const setActive = async (combo: PetCombo, isActive: boolean) => {
  try {
    await setActiveMutation.mutateAsync({ id: combo.id, isActive });
  } catch {
    // the mutation already showed the failure toast
  }
};

const archive = async () => {
  const combo = toArchive.value;
  toArchive.value = null;
  if (combo) await setActive(combo, false);
};
</script>
