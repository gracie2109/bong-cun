<template>
  <div class="space-y-3 rounded-xl border bg-white p-4">
    <div class="flex items-center justify-between">
      <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        {{ $t("petCare.pets.detail.weight") }}
      </h3>
      <Button v-if="canUpdate" size="sm" variant="outline" @click="formOpen = !formOpen">
        <Plus class="mr-1 size-4" />
        {{ $t("petCare.pets.detail.addWeight") }}
      </Button>
    </div>

    <p v-if="latest" class="text-4xl font-bold">
      {{ $t("petCare.common.kg", { n: latest.weightKg }) }}
    </p>
    <p v-else class="text-sm text-muted-foreground">{{ $t("petCare.pets.noWeight") }}</p>
    <p v-if="latest" class="text-xs font-medium" :class="bracket ? 'text-primary' : 'text-amber-600'">
      {{
        bracket
          ? $t("petCare.pets.detail.currentBracket", { label: bracket.label })
          : $t("petCare.pets.fields.noBracket")
      }}
    </p>

    <form v-if="canUpdate && formOpen" class="space-y-2 rounded-lg border bg-muted/30 p-3" @submit.prevent="submit">
      <div class="space-y-1">
        <Label for="weight-kg">{{ $t("petCare.pets.detail.weightKg") }}</Label>
        <Input id="weight-kg" v-model="weightInput" type="number" step="0.1" min="0" inputmode="decimal" />
      </div>
      <div class="space-y-1">
        <Label for="weight-note">{{ $t("petCare.pets.detail.weightNote") }}</Label>
        <Input id="weight-note" v-model="weightNote" />
      </div>
      <div class="flex justify-end gap-2">
        <Button type="button" size="sm" variant="outline" @click="formOpen = false">
          {{ $t("petCare.common.cancel") }}
        </Button>
        <Button type="submit" size="sm" :disabled="addWeight.isPending.value || !weightValid">
          {{ $t("petCare.common.save") }}
        </Button>
      </div>
    </form>

    <WeightSparkline v-if="weights.length > 1" :weights="weights" />

    <div v-if="weights.length" class="space-y-1">
      <p class="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
        {{ $t("petCare.pets.detail.weightHistory") }}
      </p>
      <ul class="max-h-40 divide-y overflow-y-auto text-sm">
        <li v-for="log in weights" :key="log.id" class="flex items-center justify-between py-1.5">
          <span>{{ formatDate(log.measuredAt) }}</span>
          <span class="font-medium">{{ $t("petCare.common.kg", { n: log.weightKg }) }}</span>
        </li>
      </ul>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Plus } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAddPetWeight } from "@/queries/pets";
import { useWeightBrackets } from "@/queries/weightBrackets";
import type { PetWeightLog } from "@/repositories/pets";
import { findBracket } from "@/repositories/weightBrackets";
import { formatDate } from "../format";
import WeightSparkline from "./WeightSparkline.vue";

const props = defineProps<{
  petId: string;
  speciesId: string;
  /** Weight logs, newest first. */
  weights: PetWeightLog[];
  canUpdate: boolean;
}>();

const formOpen = ref(false);
const weightInput = ref("");
const weightNote = ref("");
const weightValid = computed(() => weightInput.value !== "" && Number(weightInput.value) > 0);

const addWeight = useAddPetWeight();
const bracketsQuery = useWeightBrackets(
  computed(() => props.speciesId),
  { enabled: computed(() => !!props.speciesId) }
);

const latest = computed(() => props.weights[0] ?? null);
const bracket = computed(() =>
  latest.value ? findBracket(bracketsQuery.data.value ?? [], latest.value.weightKg) : undefined
);

const submit = async () => {
  if (!weightValid.value) return;
  try {
    await addWeight.mutateAsync({
      petId: props.petId,
      weightKg: Number(weightInput.value),
      note: weightNote.value.trim() || null,
    });
    weightInput.value = "";
    weightNote.value = "";
    formOpen.value = false;
  } catch {
    // the mutation already showed the failure toast; keep the form open
  }
};
</script>
