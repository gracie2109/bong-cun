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
            <template v-if="summariesQuery.isPending.value">
              <div v-for="i in 3" :key="i" class="border-b p-3"><Skeleton class="h-12 w-full" /></div>
            </template>
            <p v-else-if="visible.length === 0" class="p-6 text-center text-sm text-muted-foreground">
              {{ $t("petCare.species.empty") }}
            </p>
            <button
              v-for="item in visible"
              :key="item.id"
              type="button"
              class="flex w-full items-center gap-3 border-b px-4 py-3 text-left transition-colors last:border-b-0 hover:bg-muted/40"
              :class="item.id === selected?.id ? 'bg-primary/5' : ''"
              @click="selectedId = item.id"
            >
              <span class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                <Icon v-if="item.icon" :icon="item.icon" class="size-5" />
                <PawPrint v-else class="size-5" />
              </span>
              <span class="min-w-0 flex-1">
                <span class="flex items-center gap-2 font-semibold">
                  <span class="truncate">{{ item.name }}</span>
                  <span
                    v-if="!item.isActive"
                    class="rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold text-muted-foreground"
                  >
                    {{ $t("petCare.common.archived") }}
                  </span>
                </span>
                <span class="block text-xs text-muted-foreground">
                  {{ $t("petCare.species.counts", { pets: item.petCount, services: item.serviceCount }) }}
                </span>
              </span>
            </button>
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
import { computed, ref, watch } from "vue";
import { Icon } from "@iconify/vue";
import { Dog, PawPrint, Pencil, Plus } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { usePermission } from "@/composables/usePermission";
import { useSetSpeciesActive, useSpeciesSummaries } from "@/queries/species";
import type { Species, SpeciesSummary } from "@/repositories/species";
import { ContentWrap, Header } from "@/views/admin/components";
import PetsNav from "../PetsNav.vue";
import BracketsEditor from "./BracketsEditor.vue";
import SpeciesFormSheet from "./SpeciesFormSheet.vue";

const summariesQuery = useSpeciesSummaries();
const setActiveMutation = useSetSpeciesActive();
const { canCreate, canUpdate } = usePermission("petServices");

const showArchived = ref(false);
const selectedId = ref<string>();
const formOpen = ref(false);
const editing = ref<Species | null>(null);
const toArchive = ref<SpeciesSummary | null>(null);

const all = computed(() => summariesQuery.data.value ?? []);
const visible = computed(() => all.value.filter((item) => showArchived.value || item.isActive));
const selected = computed(() => all.value.find((item) => item.id === selectedId.value));

// Select the first species once the list loads, and when the selected one is hidden.
watch(
  visible,
  (list) => {
    if (!list.some((item) => item.id === selectedId.value)) selectedId.value = list[0]?.id;
  },
  { immediate: true }
);

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
