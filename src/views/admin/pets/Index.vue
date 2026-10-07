<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <PawPrint class="size-4 text-primary" />
      {{ $t("petCare.pets.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 class="text-2xl font-bold">
            {{ $t("petCare.pets.title") }}
            <span class="text-muted-foreground">({{ total }})</span>
          </h2>
          <p class="text-sm text-muted-foreground">{{ $t("petCare.pets.subtitle") }}</p>
        </div>
        <Button v-if="canCreate" @click="registerOpen = true">
          <Plus class="mr-2 size-4" />
          {{ $t("petCare.pets.register") }}
        </Button>
      </div>

      <PetsNav />

      <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            v-model="search"
            class="pl-9"
            :placeholder="$t('petCare.pets.searchPlaceholder')"
          />
        </div>

        <Select v-model="speciesFilter">
          <SelectTrigger class="w-40" :aria-label="$t('petCare.pets.filterSpecies')">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem :value="ALL">{{ $t("petCare.common.all") }}</SelectItem>
            <SelectItem v-for="item in species" :key="item.id" :value="item.id">
              {{ item.name }}
            </SelectItem>
          </SelectContent>
        </Select>

        <Select v-model="bracketFilter" :disabled="speciesFilter === ALL">
          <SelectTrigger class="w-44" :aria-label="$t('petCare.pets.filterBracket')">
            <SelectValue :placeholder="$t('petCare.pets.filterBracket')" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem :value="ALL">{{ $t("petCare.common.all") }}</SelectItem>
            <SelectItem v-for="item in brackets" :key="item.id" :value="item.id">
              {{ item.label }}
            </SelectItem>
          </SelectContent>
        </Select>

        <Select v-model="statusFilter">
          <SelectTrigger class="w-44" :aria-label="$t('petCare.pets.filterStatus')">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem v-for="status in STATUSES" :key="status" :value="status">
              {{ $t(`petCare.status.${status}`) }}
            </SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div class="overflow-hidden rounded-xl border bg-white">
        <div class="flex items-center justify-between gap-3 border-b bg-muted/40 px-4 py-3">
          <span class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary">
            {{ $t("petCare.common.showing", { count: pets.length, total }) }}
          </span>
          <div class="flex items-center gap-1 text-xs text-muted-foreground">
            <Button
              variant="ghost"
              size="icon"
              class="size-7"
              :disabled="pageData.pageIndex <= 1 || petsQuery.isFetching.value"
              @click="pageData.pageIndex -= 1"
            >
              <ChevronLeft class="size-4" />
            </Button>
            <span>{{ $t("petCare.common.pageOf", { page: pageData.pageIndex, pages: pageCount }) }}</span>
            <Button
              variant="ghost"
              size="icon"
              class="size-7"
              :disabled="pageData.pageIndex >= pageCount || petsQuery.isFetching.value"
              @click="pageData.pageIndex += 1"
            >
              <ChevronRight class="size-4" />
            </Button>
          </div>
        </div>

        <div class="table-scroll">
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
              <template v-if="petsQuery.isPending.value">
                <tr v-for="i in 5" :key="i" class="border-t">
                  <td colspan="5" class="px-4 py-3"><Skeleton class="h-10 w-full" /></td>
                </tr>
              </template>
              <tr v-else-if="pets.length === 0">
                <td colspan="5" class="px-4 py-10 text-center text-muted-foreground">
                  {{ $t("petCare.pets.empty") }}
                </td>
              </tr>
              <tr
                v-for="pet in pets"
                :key="pet.id"
                class="cursor-pointer border-t transition-colors hover:bg-muted/40"
                @click="openPet(pet.id)"
              >
                <td class="px-4 py-3">
                  <div class="flex min-w-0 items-center gap-3">
                    <Avatar class="size-10">
                      <AvatarImage v-if="pet.photoUrl" :src="pet.photoUrl" />
                      <AvatarFallback class="bg-primary/15 font-semibold text-primary">
                        {{ initials(pet.name) }}
                      </AvatarFallback>
                    </Avatar>
                    <div class="min-w-0">
                      <p class="flex items-center gap-2 font-semibold">
                        <span class="truncate">{{ pet.name }}</span>
                        <Icon v-if="pet.speciesIcon" :icon="pet.speciesIcon" class="size-4 shrink-0 text-muted-foreground" />
                      </p>
                      <p class="truncate text-xs text-muted-foreground">
                        {{ [pet.speciesName, pet.breed, $t(`petCare.sex.${pet.sex}`)].filter(Boolean).join(" · ") }}
                      </p>
                      <div v-if="pet.allergies || pet.behaviorNotes" class="mt-1 flex flex-wrap gap-1">
                        <span v-if="pet.allergies" class="rounded-full bg-red-100 px-2 py-0.5 text-[10px] font-semibold text-red-700">
                          {{ $t("petCare.pets.tagAllergy") }}
                        </span>
                        <span v-if="pet.behaviorNotes" class="rounded-full bg-orange-100 px-2 py-0.5 text-[10px] font-semibold text-orange-700">
                          {{ $t("petCare.pets.tagBehavior") }}
                        </span>
                      </div>
                    </div>
                  </div>
                </td>
                <td class="whitespace-nowrap px-4 py-3">{{ ageText(pet.birthDate) }}</td>
                <td class="whitespace-nowrap px-4 py-3">
                  <template v-if="pet.weightKg !== null">
                    <p class="font-medium">
                      {{ $t("petCare.common.kg", { n: pet.weightKg }) }}
                      <span v-if="pet.weightMeasuredAt" class="text-xs font-normal text-muted-foreground">
                        · {{ formatShortDate(pet.weightMeasuredAt) }}
                      </span>
                    </p>
                    <span
                      v-if="pet.bracketLabel"
                      class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary"
                    >
                      {{ pet.bracketLabel }}
                    </span>
                  </template>
                  <span v-else class="text-xs text-muted-foreground">{{ $t("petCare.pets.noWeight") }}</span>
                </td>
                <td class="px-4 py-3">
                  <template v-if="pet.ownerName">
                    <p class="font-medium">
                      {{ pet.ownerName }}
                      <span v-if="pet.ownerCount > 1" class="text-xs font-normal text-muted-foreground">
                        {{ $t("petCare.pets.owners", { n: pet.ownerCount - 1 }) }}
                      </span>
                    </p>
                    <p class="text-xs text-muted-foreground">{{ pet.ownerPhone }}</p>
                  </template>
                  <span v-else class="text-xs text-muted-foreground">{{ $t("petCare.pets.noOwner") }}</span>
                </td>
                <td class="px-4 py-3 text-right" @click.stop>
                  <DropdownMenu>
                    <DropdownMenuTrigger as-child>
                      <Button variant="ghost" size="icon" class="size-8">
                        <EllipsisVertical class="size-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem @click="openPet(pet.id)">
                        {{ $t("petCare.common.viewProfile") }}
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        v-if="canUpdate && pet.status === 'active'"
                        @click="toArchive = pet"
                      >
                        {{ $t("petCare.common.archive") }}
                      </DropdownMenuItem>
                      <DropdownMenuItem v-else-if="canUpdate" @click="restore(pet.id)">
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

    <RegisterPetSheet v-model:open="registerOpen" @registered="openPet" />

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
import { useI18n } from "vue-i18n";
import { useRouter } from "vue-router";
import { Icon } from "@iconify/vue";
import {
  ChevronLeft,
  ChevronRight,
  EllipsisVertical,
  PawPrint,
  Plus,
  Search,
} from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
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
import { usePermission } from "@/composables/usePermission";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { usePetsList, useSetPetStatus } from "@/queries/pets";
import { useSpeciesOptions } from "@/queries/species";
import { useWeightBrackets } from "@/queries/weightBrackets";
import type { PetListFilter, PetListItem, PetStatus } from "@/repositories/pets";
import { ContentWrap, Header } from "@/views/admin/components";
import RegisterPetSheet from "./components/RegisterPetSheet.vue";
import { ageOf, formatShortDate, initials } from "./format";
import PetsNav from "./PetsNav.vue";

const ALL = "all";
const PAGE_SIZE = 10;
const SEARCH_DEBOUNCE_MS = 300;
const STATUSES: PetStatus[] = ["active", "archived", "deceased"];

const { t } = useI18n();
const router = useRouter();
const { canCreate, canUpdate } = usePermission("pets");

const search = ref("");
const speciesFilter = ref(ALL);
const bracketFilter = ref(ALL);
const statusFilter = ref<PetStatus>("active");
const pageData = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize: PAGE_SIZE });
const registerOpen = ref(false);
const toArchive = ref<PetListItem | null>(null);

const debouncedSearch = refDebounced(search, SEARCH_DEBOUNCE_MS);

const filter = computed<PetListFilter>(() => ({
  search: debouncedSearch.value,
  speciesId: speciesFilter.value === ALL ? undefined : speciesFilter.value,
  bracketId: bracketFilter.value === ALL ? undefined : bracketFilter.value,
  status: statusFilter.value,
}));

const petsQuery = usePetsList(pageData, filter);
const pets = computed(() => petsQuery.data.value?.rows ?? []);
const total = computed(() => petsQuery.data.value?.total ?? 0);
const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));

const speciesQuery = useSpeciesOptions();
const species = computed(() => speciesQuery.data.value ?? []);

const bracketSpeciesId = computed(() =>
  speciesFilter.value === ALL ? undefined : speciesFilter.value
);
const bracketsQuery = useWeightBrackets(bracketSpeciesId, {
  enabled: computed(() => bracketSpeciesId.value !== undefined),
});
const brackets = computed(() => bracketsQuery.data.value ?? []);

const setStatus = useSetPetStatus();

// Any filter change goes back to the first page; a bracket of another species no longer applies.
watch([debouncedSearch, speciesFilter, bracketFilter, statusFilter], () => {
  pageData.pageIndex = INITIAL_PAGE_INDEX;
});
watch(speciesFilter, () => {
  bracketFilter.value = ALL;
});

const ageText = (birthDate: string | null): string => {
  const age = ageOf(birthDate);
  if (!age) return t("petCare.pets.ageUnknown");
  if (age.years === 0) return t("petCare.pets.ageMonths", { m: age.months });
  return age.months === 0
    ? t("petCare.pets.ageYears", { y: age.years })
    : t("petCare.pets.ageYearsMonths", { y: age.years, m: age.months });
};

const openPet = (petId: string) => router.push({ name: "petDetail", params: { petId } });

const archive = async () => {
  const pet = toArchive.value;
  toArchive.value = null;
  if (!pet) return;
  try {
    await setStatus.mutateAsync({ id: pet.id, status: "archived" });
  } catch {
    // the mutation already showed the failure toast
  }
};

const restore = async (id: string) => {
  try {
    await setStatus.mutateAsync({ id, status: "active" });
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
