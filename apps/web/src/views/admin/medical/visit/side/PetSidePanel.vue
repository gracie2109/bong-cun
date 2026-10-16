<template>
  <aside class="space-y-4 rounded-xl border bg-white p-4">
    <div class="flex items-start justify-between gap-2">
      <div>
        <h3 class="text-base font-bold">{{ pet.name }}</h3>
        <p class="text-sm text-muted-foreground">{{ info }}</p>
      </div>
      <Button v-if="canOpenPet" size="sm" variant="outline" as-child>
        <router-link :to="{ name: 'petDetail', params: { petId: pet.id } }">{{ $t("medical.side.openPet") }}</router-link>
      </Button>
    </div>

    <p v-if="pet.allergies" class="rounded-lg border border-red-300 bg-red-50 px-3 py-2 text-sm font-semibold text-red-700">
      {{ $t("medical.flags.allergy") }}: {{ pet.allergies }}
    </p>
    <p v-if="pet.behaviorNotes" class="rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900">
      {{ $t("medical.flags.behavior") }}: {{ pet.behaviorNotes }}
    </p>
    <p v-if="pet.status === 'deceased'" class="rounded-lg bg-slate-200 px-3 py-2 text-sm font-semibold text-slate-700">{{ $t("medical.side.deceased") }}</p>

    <p v-if="pet.lastWeightKg" class="text-sm">{{ $t("medical.side.lastWeight") }}: <span class="font-semibold">{{ pet.lastWeightKg }} kg</span></p>

    <HistoryList :pet-id="pet.id" :current-visit-id="currentVisitId" />
  </aside>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { Button } from "@/components/ui/button";
import { useAuthStore } from "@/stores";
import type { VisitPet } from "@bongcun/core/medical";
import HistoryList from "./HistoryList.vue";

const props = defineProps<{ pet: VisitPet; currentVisitId: string }>();
const { t } = useI18n();
const auth = useAuthStore();
const canOpenPet = computed(() => auth.can("pets", "VIEW"));

const info = computed(() =>
  [
    props.pet.speciesName,
    props.pet.breed,
    props.pet.sex ? t(`medical.sex.${props.pet.sex}`, props.pet.sex) : null,
    props.pet.neutered === null ? null : t(props.pet.neutered ? "medical.side.neutered" : "medical.side.intact"),
  ]
    .filter(Boolean)
    .join(" · ")
);
</script>
