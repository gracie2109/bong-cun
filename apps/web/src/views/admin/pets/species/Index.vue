<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <Dog class="size-4 text-primary" />
      {{ $t("petCare.species.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-2xl font-bold">{{ $t("petCare.species.title") }}</h2>
          <p class="text-sm text-muted-foreground">{{ $t("petCare.species.subtitle") }}</p>
        </div>
        <Button v-if="canCreate" @click="openCreate">
          <Plus class="mr-2 size-4" />
          {{ $t("petCare.species.add") }}
        </Button>
      </div>

      <PetsNav />

      <div class="grid gap-5 lg:grid-cols-[320px_minmax(0,1fr)]">
        <div class="space-y-3">
          <label class="flex items-center gap-2 px-1 text-sm text-muted-foreground">
            <Switch v-model="showArchived" />
            {{ $t("petCare.species.showArchived") }}
          </label>

          <div class="overflow-hidden rounded-xl border bg-white">
            <template v-if="pending">
              <div v-for="i in 3" :key="i" class="border-b p-3"><Skeleton class="h-12 w-full" /></div>
            </template>
            <p v-else-if="visible.length === 0" class="p-6 text-center text-sm text-muted-foreground">
              {{ $t("petCare.species.empty") }}
            </p>
            <SpeciesListItem
              v-for="item in visible"
              :key="item.id"
              :species="item"
              :selected="item.id === selected?.id"
              @click="selectedId = item.id"
            />
          </div>
        </div>

        <div class="rounded-xl border bg-white p-5">
          <p v-if="!selected" class="py-10 text-center text-sm text-muted-foreground">
            {{ $t("petCare.species.noSelection") }}
          </p>
          <div v-else class="space-y-6">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div class="min-w-0">
                <h3 class="text-lg font-bold">{{ selected.name }}</h3>
                <p v-if="selected.desc" class="text-sm text-muted-foreground">{{ selected.desc }}</p>
              </div>
              <div v-if="canUpdate" class="flex gap-2">
                <Button variant="outline" size="sm" @click="openEdit">
                  <Pencil class="mr-2 size-4" />
                  {{ $t("petCare.common.edit") }}
                </Button>
                <Button
                  v-if="selected.isActive"
                  variant="outline"
                  size="sm"
                  @click="toArchive = selected"
                >
                  {{ $t("petCare.common.archive") }}
                </Button>
                <Button v-else variant="outline" size="sm" @click="setActive(selected, true)">
                  {{ $t("petCare.common.restore") }}
                </Button>
              </div>
            </div>

            <BracketsEditor :species-id="selected.id" />
          </div>
        </div>
      </div>
    </div>

    <SpeciesFormSheet
      v-model:open="formOpen"
      :species="editing"
      @saved="(id) => (selectedId = id)"
    />

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
import { Dog, Pencil, Plus } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { usePermission } from "@/composables/usePermission";
import { useSetSpeciesActive } from "@/queries/species";
import type { Species, SpeciesSummary } from "@/repositories/species";
import { ContentWrap, Header } from "@/views/admin/components";
import PetsNav from "../PetsNav.vue";
import BracketsEditor from "./BracketsEditor.vue";
import SpeciesFormSheet from "./SpeciesFormSheet.vue";
import SpeciesListItem from "./SpeciesListItem.vue";
import { useSpeciesSelection } from "./useSpeciesSelection";

const setActiveMutation = useSetSpeciesActive();
const { canCreate, canUpdate } = usePermission("petServices");
const { pending, showArchived, selectedId, visible, selected } = useSpeciesSelection();

const formOpen = ref(false);
const editing = ref<Species | null>(null);
const toArchive = ref<SpeciesSummary | null>(null);

const openCreate = () => {
  editing.value = null;
  formOpen.value = true;
};

const openEdit = () => {
  editing.value = selected.value ?? null;
  formOpen.value = true;
};

const setActive = async (item: Species, isActive: boolean) => {
  try {
    await setActiveMutation.mutateAsync({ id: item.id, isActive });
  } catch {
    // the mutation already showed the failure toast
  }
};

const archive = async () => {
  const item = toArchive.value;
  toArchive.value = null;
  if (item) await setActive(item, false);
};
</script>
