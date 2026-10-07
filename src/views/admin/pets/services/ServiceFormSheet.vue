<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-lg">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ service ? $t("petCare.services.edit") : $t("petCare.services.add") }}</SheetTitle>
        <SheetDescription class="sr-only">{{ $t("petCare.services.subtitle") }}</SheetDescription>
      </SheetHeader>

      <form id="service-form" class="flex-1 space-y-5 overflow-y-auto px-6 py-5" @submit.prevent="submit()">
        <div class="space-y-2">
          <Label for="service-name">{{ $t("petCare.services.form.name") }}</Label>
          <Input id="service-name" v-model="name" />
          <p v-if="submitted && !name.trim()" class="text-sm text-red-600">{{ $t("petCare.common.required") }}</p>
        </div>

        <div class="space-y-2">
          <Label for="service-desc">{{ $t("petCare.services.form.desc") }}</Label>
          <Textarea id="service-desc" v-model="desc" class="resize-none" rows="3" />
        </div>

        <div class="space-y-2">
          <Label>{{ $t("petCare.services.form.species") }}</Label>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="item in speciesOptions"
              :key="item.id"
              type="button"
              class="flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm transition-colors"
              :class="speciesIds.includes(item.id) ? 'border-primary bg-primary/10 text-primary' : 'hover:bg-muted'"
              :aria-pressed="speciesIds.includes(item.id)"
              @click="toggleSpecies(item.id)"
            >
              <Icon v-if="item.icon" :icon="item.icon" class="size-4" />
              {{ item.name }}
            </button>
          </div>
          <p v-if="submitted && speciesIds.length === 0" class="text-sm text-red-600">
            {{ $t("petCare.services.form.errSpecies") }}
          </p>
          <p v-if="removedSpeciesCount > 0" class="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
            {{ $t("petCare.services.form.removeSpeciesWarning") }}
          </p>
        </div>

        <div class="space-y-2">
          <Label>{{ $t("petCare.services.form.pricing") }}</Label>
          <div class="grid gap-2 sm:grid-cols-2">
            <button
              v-for="option in PRICING"
              :key="option.value"
              type="button"
              class="rounded-xl border p-3 text-left transition-colors"
              :class="type === option.value ? 'border-primary bg-primary/5' : 'hover:bg-muted/40'"
              :aria-pressed="type === option.value"
              @click="type = option.value"
            >
              <span class="block text-sm font-semibold">{{ $t(option.title) }}</span>
              <span class="block text-xs text-muted-foreground">{{ $t(option.desc) }}</span>
            </button>
          </div>
        </div>

        <div v-if="type === 'all'" class="space-y-2">
          <Label for="service-price">{{ $t("petCare.services.form.fixedPrice") }}</Label>
          <Input id="service-price" v-model="price" type="number" min="0" step="1000" inputmode="numeric" />
          <p v-if="submitted && !priceValid" class="text-sm text-red-600">{{ $t("petCare.services.form.errPrice") }}</p>
        </div>

        <div class="grid gap-4 sm:grid-cols-2">
          <div class="space-y-2">
            <Label for="service-duration">{{ $t("petCare.services.form.duration") }}</Label>
            <Input id="service-duration" v-model="duration" type="number" min="0" max="1439" step="5" inputmode="numeric" />
            <p v-if="submitted && !durationValid" class="text-sm text-red-600">
              {{ $t("petCare.services.form.errDuration") }}
            </p>
          </div>
          <div class="space-y-2">
            <Label>{{ $t("petCare.services.form.unit") }}</Label>
            <Select v-model="unit">
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="unit1">{{ $t("petCare.services.form.unitTime") }}</SelectItem>
                <SelectItem value="unit2">{{ $t("petCare.services.form.unitDay") }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>

        <label class="flex items-center gap-3 text-sm">
          <Switch v-model="isShow" />
          {{ $t("petCare.services.form.showWeb") }}
        </label>
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button type="button" variant="outline" @click="emit('update:open', false)">
          {{ $t("petCare.common.cancel") }}
        </Button>
        <Button
          v-if="type === 'by_weight'"
          type="button"
          variant="outline"
          :disabled="pending"
          @click="submit(true)"
        >
          {{ $t("petCare.services.form.saveAndPrice") }}
        </Button>
        <Button type="submit" form="service-form" :disabled="pending">
          {{ $t("petCare.common.save") }}
        </Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Icon } from "@iconify/vue";
import { useRouter } from "vue-router";
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
import { useCreatePetService, useUpdatePetService } from "@/queries/petServices";
import { useSpeciesOptions } from "@/queries/species";
import type { PetService } from "@/repositories/petServices";

const MAX_DURATION_MINUTES = 1439;
const PRICING = [
  { value: "by_weight", title: "petCare.services.typeByWeight", desc: "petCare.services.form.byWeightDesc" },
  { value: "all", title: "petCare.services.typeAll", desc: "petCare.services.form.fixedDesc" },
] as const;

const props = defineProps<{ open: boolean; service: PetService | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const router = useRouter();
const speciesQuery = useSpeciesOptions();
const speciesOptions = computed(() => speciesQuery.data.value ?? []);

const name = ref("");
const desc = ref("");
const speciesIds = ref<string[]>([]);
const type = ref<"by_weight" | "all">("by_weight");
const price = ref("");
const duration = ref("60");
const unit = ref("unit1");
const isShow = ref(true);
const submitted = ref(false);

const create = useCreatePetService();
const update = useUpdatePetService();
const pending = computed(() => create.isPending.value || update.isPending.value);

watch(
  () => [props.open, props.service],
  () => {
    if (!props.open) return;
    const service = props.service;
    name.value = service?.name ?? "";
    desc.value = service?.desc ?? "";
    speciesIds.value = service?.speciesIds ?? [];
    type.value = service?.type === "all" ? "all" : "by_weight";
    price.value = service?.generalPrice != null ? String(service.generalPrice) : "";
    duration.value = String(service?.duration[0] ?? 60);
    unit.value = service?.unit ?? "unit1";
    isShow.value = service?.isShow ?? true;
    submitted.value = false;
  },
  { immediate: true }
);

const removedSpeciesCount = computed(
  () => (props.service?.speciesIds ?? []).filter((id) => !speciesIds.value.includes(id)).length
);

const priceValid = computed(() => price.value !== "" && Number(price.value) >= 0);
const durationValid = computed(() => {
  const minutes = Number(duration.value);
  return duration.value !== "" && minutes >= 0 && minutes <= MAX_DURATION_MINUTES;
});

const toggleSpecies = (id: string) => {
  speciesIds.value = speciesIds.value.includes(id)
    ? speciesIds.value.filter((item) => item !== id)
    : [...speciesIds.value, id];
};

const submit = async (thenPrice = false) => {
  submitted.value = true;
  const valid =
    name.value.trim() &&
    speciesIds.value.length > 0 &&
    durationValid.value &&
    (type.value === "by_weight" || priceValid.value);
  if (!valid) return;

  const input = {
    name: name.value.trim(),
    desc: desc.value.trim() || null,
    type: type.value,
    unit: unit.value,
    generalPrice: type.value === "all" ? Number(price.value) : null,
    duration: [Number(duration.value)],
    isShow: isShow.value,
    isActive: props.service?.isActive ?? true,
    speciesIds: speciesIds.value,
  };
  try {
    const id = props.service
      ? await update.mutateAsync({ id: props.service.id, input })
      : await create.mutateAsync(input);
    emit("update:open", false);
    if (thenPrice) {
      router.push({ name: "petPrices", query: { speciesId: speciesIds.value[0], serviceId: id } });
    }
  } catch {
    // the mutation already showed the failure toast; keep the sheet open
  }
};
</script>
