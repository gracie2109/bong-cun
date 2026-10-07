<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <Scissors class="size-4 text-primary" />
      {{ $t("petCare.services.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="relative top-10 space-y-5">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-2xl font-bold">
            {{ $t("petCare.services.title") }}
            <span class="text-muted-foreground">({{ total }})</span>
          </h2>
          <p class="text-sm text-muted-foreground">{{ $t("petCare.services.subtitle") }}</p>
        </div>
        <Button @click="openCreate">
          <Plus class="mr-2 size-4" />
          {{ $t("petCare.services.add") }}
        </Button>
      </div>

      <PetsNav />

      <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('petCare.services.searchPlaceholder')" />
        </div>
        <Select v-model="speciesFilter">
          <SelectTrigger class="w-40" :aria-label="$t('petCare.services.filterSpecies')">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem :value="ALL">{{ $t("petCare.common.all") }}</SelectItem>
            <SelectItem v-for="item in species" :key="item.id" :value="item.id">{{ item.name }}</SelectItem>
          </SelectContent>
        </Select>
        <Select v-model="typeFilter">
          <SelectTrigger class="w-48" :aria-label="$t('petCare.services.filterType')">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem :value="ALL">{{ $t("petCare.common.all") }}</SelectItem>
            <SelectItem value="by_weight">{{ $t("petCare.services.typeByWeight") }}</SelectItem>
            <SelectItem value="all">{{ $t("petCare.services.typeAll") }}</SelectItem>
          </SelectContent>
        </Select>
        <label class="flex items-center gap-2 text-sm text-muted-foreground">
          <Switch v-model="showArchived" />
          {{ $t("petCare.services.showArchived") }}
        </label>
      </div>

      <div class="overflow-hidden rounded-xl border bg-white">
        <div class="flex items-center justify-between gap-3 border-b bg-muted/40 px-4 py-3">
          <span class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary">
            {{ $t("petCare.common.showing", { count: services.length, total }) }}
          </span>
          <div class="flex items-center gap-1 text-xs text-muted-foreground">
            <Button
              variant="ghost"
              size="icon"
              class="size-7"
              :disabled="pageData.pageIndex <= 1 || servicesQuery.isFetching.value"
              @click="pageData.pageIndex -= 1"
            >
              <ChevronLeft class="size-4" />
            </Button>
            <span>{{ $t("petCare.common.pageOf", { page: pageData.pageIndex, pages: pageCount }) }}</span>
            <Button
              variant="ghost"
              size="icon"
              class="size-7"
              :disabled="pageData.pageIndex >= pageCount || servicesQuery.isFetching.value"
              @click="pageData.pageIndex += 1"
            >
              <ChevronRight class="size-4" />
            </Button>
          </div>
        </div>

        <div class="overflow-x-auto">
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
              <template v-if="servicesQuery.isPending.value">
                <tr v-for="i in 5" :key="i" class="border-t">
                  <td colspan="5" class="px-4 py-3"><Skeleton class="h-10 w-full" /></td>
                </tr>
              </template>
              <tr v-else-if="services.length === 0">
                <td colspan="5" class="px-4 py-10 text-center text-muted-foreground">
                  {{ $t("petCare.services.empty") }}
                </td>
              </tr>
              <tr v-for="service in services" :key="service.id" class="border-t" :class="service.isActive ? '' : 'opacity-60'">
                <td class="px-4 py-3">
                  <p class="flex items-center gap-2 font-semibold">
                    {{ service.name }}
                    <span
                      v-if="!service.isActive"
                      class="rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold text-muted-foreground"
                    >
                      {{ $t("petCare.common.archived") }}
                    </span>
                  </p>
                  <p v-if="service.desc" class="line-clamp-1 text-xs text-muted-foreground">{{ service.desc }}</p>
                </td>
                <td class="px-4 py-3">
                  <div class="flex flex-wrap gap-1">
                    <span
                      v-for="item in service.species"
                      :key="item.id"
                      class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary"
                    >
                      {{ item.name }}
                    </span>
                  </div>
                </td>
                <td class="px-4 py-3">
                  <template v-if="service.type === 'all'">
                    <p class="font-medium">{{ formatPrice(service.generalPrice ?? 0) }}</p>
                    <p class="text-xs text-muted-foreground">{{ $t("petCare.services.typeAll") }}</p>
                  </template>
                  <template v-else>
                    <p class="text-xs text-muted-foreground">{{ $t("petCare.services.typeByWeight") }}</p>
                    <router-link
                      class="text-xs font-semibold text-primary hover:underline"
                      :to="{ name: 'petPrices', query: { speciesId: service.speciesIds[0], serviceId: service.id } }"
                    >
                      {{ $t("petCare.services.setPrices") }}
                    </router-link>
                  </template>
                </td>
                <td class="whitespace-nowrap px-4 py-3">
                  {{ $t("petCare.services.minutes", { n: service.duration[0] }) }}
                </td>
                <td class="px-4 py-3 text-right">
                  <DropdownMenu>
                    <DropdownMenuTrigger as-child>
                      <Button variant="ghost" size="icon" class="size-8">
                        <EllipsisVertical class="size-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem @click="openEdit(service)">{{ $t("petCare.common.edit") }}</DropdownMenuItem>
                      <DropdownMenuItem v-if="service.isActive" @click="toArchive = service">
                        {{ $t("petCare.common.archive") }}
                      </DropdownMenuItem>
                      <DropdownMenuItem v-else @click="setActive(service, true)">
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
import { computed, reactive, ref, watch } from "vue";
import { refDebounced } from "@vueuse/core";
import { ChevronLeft, ChevronRight, EllipsisVertical, Plus, Scissors, Search } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { formatPrice } from "@/lib/utils";
import { usePetServicesList, useSetPetServiceActive } from "@/queries/petServices";
import { useSpeciesOptions } from "@/queries/species";
import type { PetService, PetServiceFilter } from "@/repositories/petServices";
import { ContentWrap, Header } from "@/views/admin/components";
import PetsNav from "../PetsNav.vue";
import ServiceFormSheet from "./ServiceFormSheet.vue";

const ALL = "all";
const PAGE_SIZE = 10;
const SEARCH_DEBOUNCE_MS = 300;

const search = ref("");
const speciesFilter = ref(ALL);
const typeFilter = ref(ALL);
const showArchived = ref(false);
const pageData = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize: PAGE_SIZE });
const formOpen = ref(false);
const editing = ref<PetService | null>(null);
const toArchive = ref<PetService | null>(null);

const debouncedSearch = refDebounced(search, SEARCH_DEBOUNCE_MS);

const filter = computed<PetServiceFilter>(() => ({
  search: debouncedSearch.value,
  speciesId: speciesFilter.value === ALL ? undefined : speciesFilter.value,
  type: typeFilter.value === ALL ? undefined : (typeFilter.value as "all" | "by_weight"),
  includeArchived: showArchived.value,
}));

const servicesQuery = usePetServicesList(pageData, filter);
const services = computed(() => servicesQuery.data.value?.rows ?? []);
const total = computed(() => servicesQuery.data.value?.total ?? 0);
const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));

const speciesQuery = useSpeciesOptions();
const species = computed(() => speciesQuery.data.value ?? []);
const setActiveMutation = useSetPetServiceActive();

watch([debouncedSearch, speciesFilter, typeFilter, showArchived], () => {
  pageData.pageIndex = INITIAL_PAGE_INDEX;
});

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
