<template>
  <div class="space-y-3 rounded-lg border p-3">
    <div class="flex items-center justify-between gap-2">
      <p class="text-sm font-semibold">{{ $t("boarding.dialog.petN", { n: index + 1 }) }}</p>
      <Button v-if="removable" type="button" size="sm" variant="ghost" :aria-label="$t('boarding.dialog.removePet')" @click="emit('remove')">
        <Trash2 class="size-4" />
      </Button>
    </div>

    <div class="grid gap-3 sm:grid-cols-2">
      <div class="space-y-1.5">
        <Label>{{ $t("boarding.dialog.pet") }}</Label>
        <Select :model-value="pet.petId" @update:model-value="(value) => setPet(String(value))">
          <SelectTrigger><SelectValue :placeholder="$t('boarding.dialog.pickPet')" /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="item in pets" :key="item.id" :value="item.id" :disabled="takenElsewhere(item.id)">
              {{ item.name }} · {{ item.speciesName }}
            </SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div class="space-y-1.5">
        <Label>{{ $t("boarding.dialog.kennelType") }}</Label>
        <Select :model-value="pet.kennelTypeId" :disabled="!pet.petId" @update:model-value="(value) => setType(String(value))">
          <SelectTrigger><SelectValue :placeholder="$t('boarding.dialog.pickType')" /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="type in typeOptions" :key="type.id" :value="type.id">
              {{ type.name }}<span class="text-muted-foreground"> · {{ availabilityText(type.id) }}</span>
            </SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div class="space-y-1.5">
        <Label>{{ $t("boarding.dialog.kennel") }}</Label>
        <Select v-model="pet.kennelId" :disabled="!pet.kennelTypeId || pet.shareWith !== NONE">
          <SelectTrigger><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem :value="AUTO">{{ $t("boarding.dialog.autoKennel") }}</SelectItem>
            <SelectItem v-for="kennel in kennels" :key="kennel.id" :value="kennel.id">{{ kennel.code }}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div v-if="shareChoices.length" class="space-y-1.5">
        <Label>{{ $t("boarding.dialog.shareWith") }}</Label>
        <Select v-model="pet.shareWith">
          <SelectTrigger><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem :value="NONE">{{ $t("boarding.dialog.ownKennel") }}</SelectItem>
            <SelectItem v-for="choice in shareChoices" :key="choice.line" :value="String(choice.line)">{{ choice.name }}</SelectItem>
          </SelectContent>
        </Select>
      </div>
    </div>

    <div class="grid gap-3 sm:grid-cols-3">
      <div class="space-y-1.5">
        <Label :for="`feeding-${pet.key}`">{{ $t("boarding.dialog.feeding") }}</Label>
        <Textarea :id="`feeding-${pet.key}`" v-model="pet.feeding" rows="2" :placeholder="$t('boarding.dialog.feedingHint')" />
      </div>
      <div class="space-y-1.5">
        <Label :for="`medication-${pet.key}`">{{ $t("boarding.dialog.medication") }}</Label>
        <Textarea :id="`medication-${pet.key}`" v-model="pet.medication" rows="2" />
      </div>
      <div class="space-y-1.5">
        <Label :for="`belongings-${pet.key}`">{{ $t("boarding.dialog.belongings") }}</Label>
        <Textarea :id="`belongings-${pet.key}`" v-model="pet.belongings" rows="2" :placeholder="$t('boarding.dialog.belongingsHint')" />
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { Trash2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useKennels } from "@/features/admin/boarding/queries";
import type { CustomerPet } from "@bongcun/supabase/pos";
import type { KennelType, TypeAvailability } from "@bongcun/core/boarding";
import { AUTO, NONE, typesForPet, type PetDraft } from "./stayDraft";

const FIRST_PAGE = { pageIndex: 1, pageSize: 100 };

const props = defineProps<{
  pet: PetDraft;
  index: number;
  removable: boolean;
  branchId: string;
  pets: CustomerPet[];
  types: KennelType[];
  availability: TypeAvailability[];
  /** The other pets of this booking, in order, for sharing a kennel. */
  siblings: PetDraft[];
}>();
const emit = defineEmits<{ remove: [] }>();

const { t } = useI18n();

const chosenPet = computed(() => props.pets.find((item) => item.id === props.pet.petId));
const typeOptions = computed(() => typesForPet(props.types, chosenPet.value));
const takenElsewhere = (petId: string) => props.siblings.some((other) => other.key !== props.pet.key && other.petId === petId);

const availabilityText = (typeId: string): string => {
  const row = props.availability.find((item) => item.kennelTypeId === typeId);
  if (!row) return t("boarding.dialog.noKennels");
  return t("boarding.dialog.freeOf", { free: row.free, total: row.total });
};

// Kennels of the chosen type, to pick one by hand instead of "automatic".
const kennelsQuery = useKennels(
  computed(() => (props.pet.kennelTypeId ? props.branchId : undefined)),
  FIRST_PAGE,
  computed(() => ({ typeId: props.pet.kennelTypeId }))
);
const kennels = computed(() => (kennelsQuery.data.value?.rows ?? []).filter((kennel) => kennel.isActive && kennel.status !== "maintenance"));

// Earlier pets of the same kennel type in a type that takes several pets can share a kennel.
const shareChoices = computed(() => {
  const type = props.types.find((item) => item.id === props.pet.kennelTypeId);
  if (!type || type.maxPets < 2) return [];
  return props.siblings
    .slice(0, props.index)
    .map((other, line) => ({ other, line: line + 1 }))
    .filter(({ other }) => other.kennelTypeId === props.pet.kennelTypeId && other.petId && other.shareWith === NONE)
    .map(({ other, line }) => ({ line, name: props.pets.find((item) => item.id === other.petId)?.name ?? `#${line}` }));
});

const setPet = (petId: string) => {
  props.pet.petId = petId;
  const pet = props.pets.find((item) => item.id === petId);
  // A type that does not take this species is dropped.
  if (props.pet.kennelTypeId && !typesForPet(props.types, pet).some((type) => type.id === props.pet.kennelTypeId)) {
    props.pet.kennelTypeId = "";
    props.pet.kennelId = AUTO;
    props.pet.shareWith = NONE;
  }
};

const setType = (typeId: string) => {
  props.pet.kennelTypeId = typeId;
  props.pet.kennelId = AUTO;
  props.pet.shareWith = NONE;
};
</script>
