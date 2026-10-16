<template>
  <article class="flex flex-col gap-3 rounded-xl border bg-white p-4">
    <div class="flex items-start justify-between gap-2">
      <div class="min-w-0">
        <h3 class="truncate font-semibold">{{ pet.name }}</h3>
        <p class="truncate text-sm text-muted-foreground">
          {{ [pet.speciesName, pet.breed].filter(Boolean).join(" · ") }}
        </p>
      </div>
    </div>

    <dl class="grid grid-cols-2 gap-x-3 gap-y-1 text-sm">
      <dt class="text-muted-foreground">{{ $t("client.pets.sex") }}</dt>
      <dd>{{ $t(`client.pets.sexes.${pet.sex}`) }}{{ pet.neutered ? ` · ${$t("client.pets.neuteredShort")}` : "" }}</dd>
      <dt class="text-muted-foreground">{{ $t("client.pets.age") }}</dt>
      <dd>{{ ageLabel }}</dd>
      <dt class="text-muted-foreground">{{ $t("client.pets.weight") }}</dt>
      <dd>{{ pet.weightKg === null ? "—" : $t("petCare.common.kg", { n: pet.weightKg }) }}</dd>
    </dl>

    <p v-if="pet.nextVaccine" class="text-xs text-muted-foreground">
      {{ $t("client.pets.nextVaccine", { name: pet.nextVaccine.name, date: formatDay(pet.nextVaccine.dueOn) }) }}
    </p>

    <p v-if="pet.allergies" class="rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
      {{ $t("client.pets.allergies") }}: {{ pet.allergies }}
    </p>
    <Button as-child variant="outline" size="sm" class="self-start">
      <RouterLink :to="{ name: 'account-pet-health', params: { id: pet.id } }"><HeartPulse class="mr-1.5 size-4" />{{ $t("client.pets.healthBook") }}</RouterLink>
    </Button>
  </article>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { HeartPulse } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import type { MyPet } from "@bongcun/core/account";
import { petAge } from "@bongcun/core/account";
import { formatDay } from "../health/format";

const props = defineProps<{ pet: MyPet }>();

const { t } = useI18n();
const ageLabel = computed(() => {
  const age = petAge(props.pet.birthDate);
  if (!age) return "—";
  if (age.years === 0) return t("client.pets.ageMonths", { n: age.months });
  return age.months === 0
    ? t("client.pets.ageYears", { n: age.years })
    : t("client.pets.ageYearsMonths", { y: age.years, m: age.months });
});
</script>
