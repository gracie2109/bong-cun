<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ combo ? $t("petCare.combos.edit") : $t("petCare.combos.add") }}</SheetTitle>
        <SheetDescription class="sr-only">{{ $t("petCare.combos.subtitle") }}</SheetDescription>
      </SheetHeader>

      <form id="combo-form" class="flex-1 space-y-5 overflow-y-auto px-6 py-5" @submit.prevent="submit">
        <div class="space-y-2">
          <Label for="combo-name">{{ $t("petCare.combos.form.name") }}</Label>
          <Input id="combo-name" v-model="name" />
          <p v-if="submitted && !name.trim()" class="text-sm text-red-600">{{ $t("petCare.common.required") }}</p>
        </div>

        <div class="space-y-2">
          <Label for="combo-desc">{{ $t("petCare.combos.form.desc") }}</Label>
          <Textarea id="combo-desc" v-model="desc" class="resize-none" rows="2" />
        </div>

        <div class="space-y-2">
          <Label>{{ $t("petCare.combos.form.species") }}</Label>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="item in speciesOptions"
              :key="item.id"
              type="button"
              class="flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm transition-colors"
              :class="speciesIds.includes(item.id) ? 'border-primary bg-primary/10 text-primary' : 'hover:bg-muted'"
              :aria-pressed="speciesIds.includes(item.id)"
              @click="toggle(speciesIds, item.id)"
            >
              <Icon v-if="item.icon" :icon="item.icon" class="size-4" />
              {{ item.name }}
            </button>
          </div>
          <p v-if="submitted && speciesIds.length === 0" class="text-sm text-red-600">
            {{ $t("petCare.combos.form.errSpecies") }}
          </p>
        </div>

        <div class="space-y-2">
          <Label>{{ $t("petCare.combos.form.services") }}</Label>
          <p v-if="speciesIds.length === 0" class="text-sm text-muted-foreground">
            {{ $t("petCare.combos.form.pickSpeciesFirst") }}
          </p>
          <template v-else>
            <p class="text-xs text-muted-foreground">{{ $t("petCare.combos.form.servicesHint") }}</p>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="item in serviceOptions"
                :key="item.id"
                type="button"
                class="rounded-full border px-3 py-1.5 text-sm transition-colors"
                :class="serviceIds.includes(item.id) ? 'border-primary bg-primary/10 text-primary' : 'hover:bg-muted'"
                :aria-pressed="serviceIds.includes(item.id)"
                @click="toggle(serviceIds, item.id)"
              >
                {{ item.name }}
              </button>
            </div>
          </template>
          <p v-if="submitted && serviceIds.length === 0" class="text-sm text-red-600">
            {{ $t("petCare.combos.form.errServices") }}
          </p>
        </div>

        <div class="grid gap-4 sm:grid-cols-2">
          <div class="space-y-2">
            <Label for="combo-origin">{{ $t("petCare.combos.form.originPrice") }}</Label>
            <Input id="combo-origin" :model-value="originPrice" disabled />
          </div>
          <div class="space-y-2">
            <Label for="combo-price">{{ $t("petCare.combos.form.price") }}</Label>
            <Input id="combo-price" v-model="price" type="number" min="0" step="1000" inputmode="numeric" />
            <p v-if="submitted && !priceValid" class="text-sm text-red-600">{{ $t("petCare.services.form.errPrice") }}</p>
            <p v-if="savings > 0" class="text-xs font-medium text-green-700">
              {{ $t("petCare.combos.form.savings", { amount: formatPrice(savings) }) }}
            </p>
          </div>
          <div class="space-y-2">
            <Label for="combo-duration">{{ $t("petCare.combos.form.duration") }}</Label>
            <Input id="combo-duration" v-model="duration" type="number" min="0" max="1439" step="5" inputmode="numeric" />
            <p v-if="totalDuration > 0" class="text-xs text-muted-foreground">
              {{ $t("petCare.combos.form.totalDuration", { n: totalDuration }) }}
            </p>
          </div>
          <div class="space-y-2">
            <Label>{{ $t("petCare.combos.form.mark") }}</Label>
            <Select v-model="markAsId">
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="mark in MARKS" :key="mark" :value="mark">
                  {{ $t(`petCare.combos.marks.${mark}`) }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>

        <div class="space-y-2">
          <Label>{{ $t("petCare.combos.form.promoTime") }}</Label>
          <div class="grid gap-4 sm:grid-cols-2">
            <div class="space-y-1">
              <Label for="combo-from" class="text-xs text-muted-foreground">{{ $t("petCare.combos.form.from") }}</Label>
              <Input id="combo-from" v-model="promoFrom" type="date" />
            </div>
            <div class="space-y-1">
              <Label for="combo-to" class="text-xs text-muted-foreground">{{ $t("petCare.combos.form.to") }}</Label>
              <Input id="combo-to" v-model="promoTo" type="date" :min="promoFrom" />
            </div>
          </div>
        </div>

        <label class="flex items-center gap-3 text-sm">
          <Switch v-model="sellable" />
          {{ $t("petCare.combos.form.sellable") }}
        </label>
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button type="button" variant="outline" @click="emit('update:open', false)">
          {{ $t("petCare.common.cancel") }}
        </Button>
        <Button type="submit" form="combo-form" :disabled="pending">{{ $t("petCare.common.save") }}</Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Icon } from "@iconify/vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import { formatPrice } from "@/lib/utils";
import { useCreatePetCombo, useUpdatePetCombo } from "@/queries/petCombos";
import { useAllPetServices } from "@/queries/petServices";
import { useSpeciesOptions } from "@/queries/species";
import type { PetCombo } from "@/repositories/petCombos";

const MARKS = ["1", "2", "3", "4"];
const DEFAULT_MARK = "4";
const STATUS_SELLING = 1;
const STATUS_STOPPED = 2;

const props = defineProps<{ open: boolean; combo: PetCombo | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const speciesQuery = useSpeciesOptions();
const speciesOptions = computed(() => speciesQuery.data.value ?? []);
const servicesQuery = useAllPetServices();

const name = ref("");
const desc = ref("");
const speciesIds = ref<string[]>([]);
const serviceIds = ref<string[]>([]);
const price = ref("");
const duration = ref("0");
const markAsId = ref(DEFAULT_MARK);
const promoFrom = ref("");
const promoTo = ref("");
const sellable = ref(true);
const submitted = ref(false);

const create = useCreatePetCombo();
const update = useUpdatePetCombo();
const pending = computed(() => create.isPending.value || update.isPending.value);

const dateInput = (iso: string | undefined): string => (iso ? iso.slice(0, 10) : "");

watch(
  () => [props.open, props.combo],
  () => {
    if (!props.open) return;
    const combo = props.combo;
    name.value = combo?.name ?? "";
    desc.value = combo?.desc ?? "";
    speciesIds.value = combo?.speciesIds ?? [];
    serviceIds.value = combo?.serviceIds ?? [];
    price.value = combo?.price != null ? String(combo.price) : "";
    duration.value = String(combo?.duration[0] ?? 0);
    markAsId.value = combo?.markAsId ?? DEFAULT_MARK;
    promoFrom.value = dateInput(combo?.markTime[0]);
    promoTo.value = dateInput(combo?.markTime[1]);
    sellable.value = (combo?.status ?? STATUS_SELLING) === STATUS_SELLING;
    submitted.value = false;
  },
  { immediate: true }
);

// Only services offered for every chosen species can be bundled (the database checks this too).
const serviceOptions = computed(() =>
  (servicesQuery.data.value ?? []).filter((service) =>
    speciesIds.value.every((id) => service.speciesIds.includes(id))
  )
);
const chosenServices = computed(() =>
  (servicesQuery.data.value ?? []).filter((service) => serviceIds.value.includes(service.id))
);

const originTotal = computed(() =>
  chosenServices.value.reduce((sum, service) => sum + (service.generalPrice ?? 0), 0)
);
const originPrice = computed(() => (originTotal.value > 0 ? formatPrice(originTotal.value) ?? "" : ""));
const totalDuration = computed(() =>
  chosenServices.value.reduce((sum, service) => sum + (service.duration[0] ?? 0), 0)
);
const savings = computed(() => (price.value === "" ? 0 : Math.max(0, originTotal.value - Number(price.value))));
const priceValid = computed(() => price.value !== "" && Number(price.value) >= 0);

const toggle = (list: string[], id: string) => {
  const index = list.indexOf(id);
  if (index >= 0) list.splice(index, 1);
  else list.push(id);
};

// Dropping a species drops the services that no longer fit all remaining species.
watch(speciesIds, () => {
  const allowed = new Set(serviceOptions.value.map((service) => service.id));
  serviceIds.value = serviceIds.value.filter((id) => allowed.has(id));
}, { deep: true });

const submit = async () => {
  submitted.value = true;
  if (!name.value.trim() || speciesIds.value.length === 0 || serviceIds.value.length === 0 || !priceValid.value) return;

  const hasWindow = promoFrom.value !== "" && promoTo.value !== "";
  const input = {
    name: name.value.trim(),
    desc: desc.value.trim() || null,
    origin_price: originTotal.value > 0 ? originTotal.value : null,
    price: Number(price.value),
    duration: [Number(duration.value || 0)],
    markAsId: markAsId.value,
    markTime: hasWindow ? [`${promoFrom.value}T00:00:00`, `${promoTo.value}T23:59:59`] : [],
    status: sellable.value ? STATUS_SELLING : STATUS_STOPPED,
    isActive: props.combo?.isActive ?? true,
    speciesIds: [...speciesIds.value],
    serviceIds: [...serviceIds.value],
  };
  try {
    if (props.combo) await update.mutateAsync({ id: props.combo.id, input });
    else await create.mutateAsync(input);
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast; keep the sheet open
  }
};
</script>
