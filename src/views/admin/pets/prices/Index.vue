<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <Banknote class="size-4 text-primary" />
      {{ $t("petCare.prices.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="relative top-10 space-y-5" :class="dirtyCount > 0 ? 'pb-20' : ''">
      <div>
        <h2 class="text-2xl font-bold">{{ $t("petCare.prices.title") }}</h2>
        <p class="text-sm text-muted-foreground">{{ $t("petCare.prices.subtitle") }}</p>
      </div>

      <PetsNav />

      <p v-if="!speciesQuery.isPending.value && species.length === 0" class="text-sm text-muted-foreground">
        {{ $t("petCare.prices.noSpecies") }}
      </p>

      <template v-else>
        <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
          <div class="flex flex-wrap gap-1">
            <button
              v-for="item in species"
              :key="item.id"
              type="button"
              class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold transition-colors"
              :class="item.id === speciesId ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
              @click="pickSpecies(item.id)"
            >
              <Icon v-if="item.icon" :icon="item.icon" class="size-4" />
              {{ item.name }}
            </button>
          </div>

          <div class="ml-auto flex flex-wrap items-center gap-3">
            <Select v-model="scope" :disabled="dirtyCount > 0">
              <SelectTrigger class="w-56" :aria-label="$t('petCare.prices.scope')"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem :value="SHARED">{{ $t("petCare.prices.scopeShared") }}</SelectItem>
                <SelectItem v-for="branch in branches" :key="branch.id" :value="branch.id">
                  {{ $t("petCare.prices.scopeBranch", { code: branch.code }) }}
                </SelectItem>
              </SelectContent>
            </Select>
            <label class="flex items-center gap-2 text-sm text-muted-foreground">
              <Switch v-model="onlyMissing" />
              {{ $t("petCare.prices.onlyMissing") }}
            </label>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3 text-sm">
          <span class="font-semibold">{{ $t("petCare.prices.fill") }}</span>
          <Label for="fill-start" class="text-xs text-muted-foreground">{{ $t("petCare.prices.fillStart") }}</Label>
          <Input id="fill-start" v-model="fillStart" type="number" min="0" step="1000" class="w-32" />
          <Label for="fill-step" class="text-xs text-muted-foreground">{{ $t("petCare.prices.fillStep") }}</Label>
          <Input id="fill-step" v-model="fillStep" type="number" min="0" step="1000" class="w-32" />
        </div>

        <p v-if="bracketsQuery.isSuccess.value && brackets.length === 0" class="rounded-xl border bg-white p-6 text-center text-sm text-muted-foreground">
          {{ $t("petCare.prices.noBrackets") }}
        </p>
        <p v-else-if="servicesQuery.isSuccess.value && services.length === 0" class="rounded-xl border bg-white p-6 text-center text-sm text-muted-foreground">
          {{ $t("petCare.prices.noServices") }}
        </p>

        <div v-else class="overflow-x-auto rounded-xl border bg-white">
          <p class="border-b bg-muted/40 px-4 py-3 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            {{ $t("petCare.prices.weightRows") }}
          </p>
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
                <th class="sticky left-0 bg-white px-4 py-3 font-semibold">{{ $t("petCare.prices.service") }}</th>
                <th v-for="bracket in brackets" :key="bracket.id" class="px-2 py-3 font-semibold">
                  {{ bracket.label }}
                </th>
                <th class="px-2 py-3"></th>
              </tr>
            </thead>
            <tbody>
              <template v-if="pricesQuery.isPending.value || bracketsQuery.isPending.value">
                <tr v-for="i in 3" :key="i" class="border-t">
                  <td :colspan="brackets.length + 2" class="px-4 py-3"><Skeleton class="h-10 w-full" /></td>
                </tr>
              </template>
              <tr
                v-for="service in visibleServices"
                :key="service.id"
                class="border-t"
                :class="service.id === highlightServiceId ? 'bg-primary/5' : ''"
              >
                <td class="sticky left-0 bg-inherit px-4 py-2 font-medium">{{ service.name }}</td>
                <td v-for="bracket in brackets" :key="bracket.id" class="px-2 py-2">
                  <Input
                    :model-value="cellValue(service.id, bracket.id)"
                    type="number"
                    min="0"
                    step="1000"
                    inputmode="numeric"
                    class="h-9 w-28"
                    :class="[
                      isEdited(service.id, bracket.id) ? 'border-primary' : '',
                      cellValue(service.id, bracket.id) === '' ? 'border-dashed border-amber-400' : '',
                    ]"
                    :placeholder="placeholderOf(service.id, bracket.id)"
                    :aria-label="`${service.name} - ${bracket.label}`"
                    @update:model-value="setCell(service.id, bracket.id, String($event ?? ''))"
                  />
                </td>
                <td class="whitespace-nowrap px-2 py-2 text-right">
                  <Button type="button" variant="ghost" size="sm" @click="fillRow(service.id)">
                    {{ $t("petCare.prices.fillRow") }}
                  </Button>
                  <Button type="button" variant="ghost" size="sm" @click="clearRow(service.id)">
                    {{ $t("petCare.prices.clearRow") }}
                  </Button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

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

    <div
      v-if="dirtyCount > 0"
      class="fixed inset-x-0 bottom-0 z-20 flex items-center justify-end gap-3 border-t bg-white px-6 py-3 shadow-lg"
    >
      <span class="text-sm text-muted-foreground">{{ $t("petCare.prices.edited", { n: dirtyCount }) }}</span>
      <Button variant="outline" :disabled="saveMutation.isPending.value" @click="edits = new Map()">
        {{ $t("petCare.prices.discard") }}
      </Button>
      <Button :disabled="saveMutation.isPending.value" @click="saveAll">{{ $t("petCare.prices.saveAll") }}</Button>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Icon } from "@iconify/vue";
import { useRoute } from "vue-router";
import { Banknote } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { useBranches } from "@/queries/branches";
import { useAllPetServices } from "@/queries/petServices";
import { priceByCell, useSaveServicePrices, useServicePrices } from "@/queries/servicePrices";
import { useSpeciesOptions } from "@/queries/species";
import { useWeightBrackets } from "@/queries/weightBrackets";
import { ContentWrap, Header } from "@/views/admin/components";
import PetsNav from "../PetsNav.vue";
import PriceLookup from "./PriceLookup.vue";

const SHARED = "shared";
const cellKey = (serviceId: string, bracketId: string) => `${serviceId}:${bracketId}`;

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

const speciesQuery = useSpeciesOptions();
const species = computed(() => speciesQuery.data.value ?? []);
const speciesId = ref<string | undefined>(queryString("speciesId"));
// Default to the first species once the list is loaded.
watch(
  species,
  (list) => {
    if (!list.some((item) => item.id === speciesId.value)) speciesId.value = list[0]?.id;
  },
  { immediate: true }
);

const branchesQuery = useBranches();
const branches = computed(() => branchesQuery.data.value ?? []);
const scope = ref(SHARED);
const branchId = computed(() => (scope.value === SHARED ? null : scope.value));

const bracketsQuery = useWeightBrackets(speciesId, { enabled: computed(() => !!speciesId.value) });
const brackets = computed(() => bracketsQuery.data.value ?? []);

const servicesQuery = useAllPetServices();
const services = computed(() =>
  (servicesQuery.data.value ?? []).filter(
    (service) => service.type === "by_weight" && !!speciesId.value && service.speciesIds.includes(speciesId.value)
  )
);

const pricesQuery = useServicePrices(computed(() => ({ speciesId: speciesId.value, branchId: branchId.value })));
const sharedQuery = useServicePrices(computed(() => ({ speciesId: speciesId.value, branchId: null })));
const saved = computed(() => priceByCell(pricesQuery.data.value ?? []));
const shared = computed(() => priceByCell(sharedQuery.data.value ?? []));

// What a customer would actually pay at the current scope: override first, else the shared price.
const effectivePrices = computed(() => new Map([...shared.value, ...saved.value]));

// Edits not saved yet, keyed by "serviceId:bracketId"; an empty string clears the cell.
const edits = ref(new Map<string, string>());
const dirtyCount = computed(() => edits.value.size);

const savedText = (serviceId: string, bracketId: string): string => {
  const value = saved.value.get(cellKey(serviceId, bracketId));
  return value === undefined ? "" : String(value);
};
const cellValue = (serviceId: string, bracketId: string): string =>
  edits.value.get(cellKey(serviceId, bracketId)) ?? savedText(serviceId, bracketId);
const isEdited = (serviceId: string, bracketId: string) => edits.value.has(cellKey(serviceId, bracketId));
const placeholderOf = (serviceId: string, bracketId: string): string => {
  const inherited = scope.value === SHARED ? undefined : shared.value.get(cellKey(serviceId, bracketId));
  return inherited === undefined ? "" : String(inherited);
};

const setCell = (serviceId: string, bracketId: string, value: string) => {
  const next = new Map(edits.value);
  if (value === savedText(serviceId, bracketId)) next.delete(cellKey(serviceId, bracketId));
  else next.set(cellKey(serviceId, bracketId), value);
  edits.value = next;
};

const fillStart = ref("");
const fillStep = ref("");
const fillRow = (serviceId: string) => {
  if (fillStart.value === "") return;
  const start = Number(fillStart.value);
  const step = Number(fillStep.value || 0);
  brackets.value.forEach((bracket, index) => setCell(serviceId, bracket.id, String(start + step * index)));
};
const clearRow = (serviceId: string) => {
  brackets.value.forEach((bracket) => setCell(serviceId, bracket.id, ""));
};

const onlyMissing = ref(false);
const visibleServices = computed(() =>
  onlyMissing.value
    ? services.value.filter((service) => brackets.value.some((bracket) => cellValue(service.id, bracket.id) === ""))
    : services.value
);

// Edits belong to one species and scope: drop them when either changes.
const pickSpecies = (id: string) => {
  speciesId.value = id;
};
watch([speciesId, scope], () => {
  edits.value = new Map();
});

const saveMutation = useSaveServicePrices();
const saveAll = async () => {
  if (!speciesId.value) return;
  const touched = new Set([...edits.value.keys()].map((key) => key.split(":")[0]));
  try {
    for (const serviceId of touched) {
      const rows = brackets.value
        .map((bracket) => ({ bracketId: bracket.id, price: cellValue(serviceId, bracket.id) }))
        .filter((row) => row.price !== "")
        .map((row) => ({ bracketId: row.bracketId, price: Number(row.price) }));
      await saveMutation.mutateAsync({
        speciesId: speciesId.value,
        serviceId,
        branchId: branchId.value,
        rows,
      });
    }
    edits.value = new Map();
  } catch {
    // the mutation already showed the failure toast; keep the edits
  }
};
</script>
