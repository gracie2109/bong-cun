<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <Banknote class="size-4 text-primary" />
      {{ $t("petCare.prices.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5" :class="dirtyCount > 0 ? 'pb-20' : ''">
      <div>
        <h2 class="text-2xl font-bold">{{ $t("petCare.prices.title") }}</h2>
        <p class="text-sm text-muted-foreground">{{ $t("petCare.prices.subtitle") }}</p>
      </div>

      <PetsNav />

      <p v-if="!speciesQuery.isPending.value && species.length === 0" class="text-sm text-muted-foreground">
        {{ $t("petCare.prices.noSpecies") }}
      </p>

      <template v-else>
        <PriceScopeBar
          v-model:species-id="speciesId"
          v-model:scope="scope"
          v-model:only-missing="onlyMissing"
          :species="species"
          :branches="branches"
          :locked="dirtyCount > 0"
        />

        <PriceFillBar v-model:start="fillStart" v-model:step="fillStep" />

        <p v-if="bracketsQuery.isSuccess.value && brackets.length === 0" class="rounded-xl border bg-white p-6 text-center text-sm text-muted-foreground">
          {{ $t("petCare.prices.noBrackets") }}
        </p>
        <p v-else-if="servicesQuery.isSuccess.value && services.length === 0" class="rounded-xl border bg-white p-6 text-center text-sm text-muted-foreground">
          {{ $t("petCare.prices.noServices") }}
        </p>

        <PriceGrid
          v-else
          :services="visibleServices"
          :brackets="brackets"
          :loading="pricesQuery.isPending.value || bracketsQuery.isPending.value"
          :can-update="canUpdate"
          :highlight-service-id="highlightServiceId"
          :cell-value="cellValue"
          :is-edited="isEdited"
          :placeholder-of="placeholderOf"
          @set-cell="setCell"
          @fill-row="fillRow"
          @clear-row="clearRow"
        />

        <p v-if="scope !== SHARED" class="text-xs text-muted-foreground">
          {{ $t("petCare.prices.resetToShared") }}: {{ $t("petCare.prices.clearRow") }}
        </p>
        <p class="text-xs text-muted-foreground">{{ $t("petCare.prices.fixedPriceSaved") }}</p>

        <PriceLookup
          :services="services"
          :brackets="brackets"
          :prices="effectivePrices"
          :initial-weight="initialWeight"
        />
      </template>
    </div>

    <PriceSaveBar
      v-if="canUpdate && dirtyCount > 0"
      :count="dirtyCount"
      :saving="saving"
      @discard="discard"
      @save="saveAll"
    />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import { Banknote } from "lucide-vue-next";
import { usePermission } from "@/composables/usePermission";
import { ContentWrap, Header } from "@/views/admin/components";
import PetsNav from "../PetsNav.vue";
import PriceFillBar from "./PriceFillBar.vue";
import PriceGrid from "./PriceGrid.vue";
import PriceLookup from "./PriceLookup.vue";
import PriceSaveBar from "./PriceSaveBar.vue";
import PriceScopeBar from "./PriceScopeBar.vue";
import { SHARED, usePriceCatalog } from "./usePriceCatalog";
import { usePriceEdits } from "./usePriceEdits";

const route = useRoute();
const queryString = (name: string): string | undefined => {
  const value = route.query[name];
  return typeof value === "string" && value ? value : undefined;
};
const initialWeight = (() => {
  const raw = Number(queryString("weight"));
  return queryString("weight") && !Number.isNaN(raw) ? raw : undefined;
})();
const highlightServiceId = queryString("serviceId");

const { canUpdate } = usePermission("petServices");

const catalog = usePriceCatalog(queryString("speciesId"));
const {
  speciesQuery,
  species,
  speciesId,
  branches,
  scope,
  bracketsQuery,
  brackets,
  servicesQuery,
  services,
  pricesQuery,
  effectivePrices,
} = catalog;

const {
  dirtyCount,
  fillStart,
  fillStep,
  saving,
  cellValue,
  isEdited,
  placeholderOf,
  setCell,
  fillRow,
  clearRow,
  discard,
  saveAll,
} = usePriceEdits(catalog);

const onlyMissing = ref(false);
const visibleServices = computed(() =>
  onlyMissing.value
    ? services.value.filter((service) => brackets.value.some((bracket) => cellValue(service.id, bracket.id) === ""))
    : services.value
);
</script>
