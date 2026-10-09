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
          <ChipPicker v-model="speciesIds" :options="speciesOptions" />
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
              v-for="option in SERVICE_PRICING"
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
            <Input id="service-duration" v-model="duration" type="number" min="0" :max="MAX_DURATION_MINUTES" step="5" inputmode="numeric" />
            <p v-if="submitted && !durationValid" class="text-sm text-red-600">
              {{ $t("petCare.services.form.errDuration") }}
            </p>
          </div>
          <div class="space-y-2">
            <Label>{{ $t("petCare.services.form.unit") }}</Label>
            <Select v-model="unit">
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="option in SERVICE_UNITS" :key="option.value" :value="option.value">{{ $t(option.label) }}</SelectItem>
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
import { computed } from "vue";
import { useRouter } from "vue-router";
import ChipPicker from "@/components/common/ChipPicker.vue";
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
import { MAX_DURATION_MINUTES, SERVICE_PRICING, SERVICE_UNITS } from "./serviceForm";
import { useServiceForm } from "./useServiceForm";

const props = defineProps<{ open: boolean; service: PetService | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const router = useRouter();
const speciesQuery = useSpeciesOptions();
const speciesOptions = computed(() => speciesQuery.data.value ?? []);

const {
  name,
  desc,
  speciesIds,
  type,
  price,
  duration,
  unit,
  isShow,
  submitted,
  removedSpeciesCount,
  priceValid,
  durationValid,
  toInput,
} = useServiceForm(
  () => props.open,
  () => props.service
);

const create = useCreatePetService();
const update = useUpdatePetService();
const pending = computed(() => create.isPending.value || update.isPending.value);

const submit = async (thenPrice = false) => {
  const input = toInput();
  if (!input) return;
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
