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
        <div class="flex items-center gap-1 text-xs text-muted-foreground">
          <Button
            variant="ghost"
            size="icon"
            class="size-7"
            :disabled="pageData.pageIndex <= 1 || combosQuery.isFetching.value"
            @click="pageData.pageIndex -= 1"
          >
            <ChevronLeft class="size-4" />
          </Button>
          <span>{{ $t("petCare.common.pageOf", { page: pageData.pageIndex, pages: pageCount }) }}</span>
          <Button
            variant="ghost"
            size="icon"
            class="size-7"
            :disabled="pageData.pageIndex >= pageCount || combosQuery.isFetching.value"
            @click="pageData.pageIndex += 1"
          >
            <ChevronRight class="size-4" />
          </Button>
        </div>
      </div>

      <div class="table-scroll rounded-xl border bg-white">
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
            <template v-if="combosQuery.isPending.value">
              <tr v-for="i in 4" :key="i" class="border-t">
                <td colspan="6" class="px-4 py-3"><Skeleton class="h-10 w-full" /></td>
              </tr>
            </template>
            <tr v-else-if="combos.length === 0">
              <td colspan="6" class="px-4 py-10 text-center text-muted-foreground">{{ $t("petCare.combos.empty") }}</td>
            </tr>
            <tr v-for="combo in combos" :key="combo.id" class="border-t" :class="combo.isActive ? '' : 'opacity-60'">
              <td class="px-4 py-3">
                <p class="flex flex-wrap items-center gap-2 font-semibold">
                  {{ combo.name }}
                  <span
                    v-if="combo.markAsId && combo.markAsId !== '4'"
                    class="rounded-full bg-primary/10 px-2 py-0.5 text-[10px] font-semibold text-primary"
                  >
                    {{ $t(`petCare.combos.marks.${combo.markAsId}`) }}
                  </span>
                </p>
                <p v-if="combo.desc" class="line-clamp-1 text-xs text-muted-foreground">{{ combo.desc }}</p>
              </td>
              <td class="px-4 py-3">
                <div class="flex flex-wrap gap-1">
                  <span
                    v-for="item in combo.species"
                    :key="item.id"
                    class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary"
                  >
                    {{ item.name }}
                  </span>
                </div>
              </td>
              <td class="px-4 py-3 text-xs text-muted-foreground">
                {{ combo.serviceProfiles.map((service) => service.name).join(", ") }}
              </td>
              <td class="whitespace-nowrap px-4 py-3">
                <p class="font-semibold">{{ formatPrice(combo.price ?? 0) }}</p>
                <p v-if="combo.origin_price" class="text-xs text-muted-foreground line-through">
                  {{ formatPrice(combo.origin_price) }}
                </p>
              </td>
              <td class="px-4 py-3">
                <span class="rounded-full px-2 py-0.5 text-[11px] font-semibold" :class="statusClass(combo)">
                  {{ $t(`petCare.combos.status.${comboStatus(combo)}`) }}
                </span>
              </td>
              <td class="px-4 py-3 text-right">
                <DropdownMenu v-if="canUpdate">
                  <DropdownMenuTrigger as-child>
                    <Button variant="ghost" size="icon" class="size-8"><EllipsisVertical class="size-4" /></Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem @click="openEdit(combo)">{{ $t("petCare.common.edit") }}</DropdownMenuItem>
                    <DropdownMenuItem v-if="combo.isActive" @click="toArchive = combo">
                      {{ $t("petCare.common.archive") }}
                    </DropdownMenuItem>
                    <DropdownMenuItem v-else @click="setActive(combo, true)">
                      {{ $t("petCare.common.restore") }}
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </td>
            </tr>
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
import { computed, reactive, ref, watch } from "vue";
import { ChevronLeft, ChevronRight, EllipsisVertical, Layers2, Plus } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { formatPrice } from "@/lib/utils";
import { usePermission } from "@/composables/usePermission";
import { usePetCombosList, useSetPetComboActive } from "@/queries/petCombos";
import type { PetCombo } from "@/repositories/petCombos";
import { ContentWrap, Header } from "@/views/admin/components";
import PetsNav from "../PetsNav.vue";
import ComboFormSheet from "./ComboFormSheet.vue";

const PAGE_SIZE = 10;
const STATUS_SELLING = 1;

const pageData = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize: PAGE_SIZE });
const showArchived = ref(false);
const formOpen = ref(false);
const editing = ref<PetCombo | null>(null);
const toArchive = ref<PetCombo | null>(null);

const combosQuery = usePetCombosList(pageData, showArchived);
const { canCreate, canUpdate } = usePermission("petServices");
const combos = computed(() => combosQuery.data.value?.rows ?? []);
const total = computed(() => combosQuery.data.value?.total ?? 0);
const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));
const setActiveMutation = useSetPetComboActive();

watch(showArchived, () => {
  pageData.pageIndex = INITIAL_PAGE_INDEX;
});

type ComboStatus = "selling" | "stopped" | "expired";
const comboStatus = (combo: PetCombo): ComboStatus => {
  if (combo.status !== STATUS_SELLING) return "stopped";
  const end = combo.markTime[1];
  return end && new Date(end).getTime() < Date.now() ? "expired" : "selling";
};
const STATUS_CLASS: Record<ComboStatus, string> = {
  selling: "bg-green-100 text-green-700",
  stopped: "bg-muted text-muted-foreground",
  expired: "bg-amber-100 text-amber-700",
};
const statusClass = (combo: PetCombo): string => STATUS_CLASS[comboStatus(combo)];

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
