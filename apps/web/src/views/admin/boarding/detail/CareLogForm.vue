<template>
  <form class="grid gap-3 rounded-xl border bg-white p-4 sm:grid-cols-2" @submit.prevent="submit">
    <div v-if="pets.length > 1" class="space-y-1.5">
      <Label>{{ $t("boarding.dialog.pet") }}</Label>
      <Select v-model="petId">
        <SelectTrigger><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem v-for="pet in pets" :key="pet.id" :value="pet.id">{{ pet.petName }}</SelectItem>
        </SelectContent>
      </Select>
    </div>
    <div class="space-y-1.5">
      <Label>{{ $t("boarding.care.kind") }}</Label>
      <Select v-model="kind">
        <SelectTrigger><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem v-for="item in CARE_KINDS" :key="item" :value="item">{{ $t(`boarding.care.kinds.${item}`) }}</SelectItem>
        </SelectContent>
      </Select>
    </div>
    <div v-if="kind === 'meal'" class="space-y-1.5">
      <Label>{{ $t("boarding.care.eaten") }}</Label>
      <Select v-model="mealEaten">
        <SelectTrigger><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem v-for="item in MEAL_EATEN" :key="item" :value="item">{{ $t(`boarding.care.meal.${item}`) }}</SelectItem>
        </SelectContent>
      </Select>
    </div>
    <div class="space-y-1.5 sm:col-span-2">
      <Label for="care-content">{{ $t("boarding.care.content") }}</Label>
      <Textarea id="care-content" v-model="content" rows="2" :placeholder="$t('boarding.care.contentHint')" />
    </div>
    <div class="flex flex-wrap items-center justify-between gap-3 sm:col-span-2">
      <label class="flex items-center gap-2 text-sm">
        <Switch v-model="visible" />
        {{ $t("boarding.care.visible") }}
      </label>
      <Button type="submit" :disabled="!valid || adding.isPending.value">
        <Loader2 v-if="adding.isPending.value" class="mr-2 size-4 animate-spin" />
        {{ $t("boarding.care.add") }}
      </Button>
    </div>
  </form>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Loader2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import { useAddCareLog } from "@/queries/boarding";
import { CARE_KINDS, MEAL_EATEN, type CareKind, type MealEaten, type StayPet } from "@/types/boarding";

const props = defineProps<{ pets: StayPet[] }>();

const adding = useAddCareLog();
const petId = ref(props.pets[0]?.id ?? "");
const kind = ref<CareKind>("meal");
const mealEaten = ref<MealEaten>("all");
const content = ref("");
const visible = ref(true);

// A meal needs no words; everything else does.
const valid = computed(() => !!petId.value && (kind.value === "meal" || content.value.trim() !== ""));

const submit = async () => {
  if (!valid.value) return;
  try {
    await adding.mutateAsync({
      stayPetId: petId.value,
      input: { kind: kind.value, mealEaten: mealEaten.value, content: content.value, visibleToCustomer: visible.value },
    });
    content.value = "";
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
