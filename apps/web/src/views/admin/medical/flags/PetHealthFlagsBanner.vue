<template>
  <div v-if="rows.length" class="space-y-1.5">
    <p v-for="row in rows" :key="row.id" class="rounded-lg border px-3 py-2 text-sm" :class="row.tone">
      <span class="font-semibold">{{ row.name }}</span>: {{ row.text }}
    </p>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { usePetHealthFlags } from "@/queries/medicalFlags";

/** Red for a recent contagious disease, yellow for an overdue vaccine or an allergy, per pet. */
const props = defineProps<{ pets: { id: string; name: string }[] }>();
const { t } = useI18n();

const query = usePetHealthFlags(computed(() => props.pets.map((pet) => pet.id)));

const RED = "border-red-200 bg-red-50 text-red-800";
const AMBER = "border-amber-200 bg-amber-50 text-amber-800";

const rows = computed(() =>
  props.pets.flatMap((pet) => {
    const flags = query.data.value?.[pet.id];
    if (!flags) return [];
    const out: { id: string; name: string; text: string; tone: string }[] = [];
    if (flags.contagious) out.push({ id: `${pet.id}-c`, name: pet.name, text: t("medical.flags.contagious"), tone: RED });
    if (flags.vaccineOverdue) out.push({ id: `${pet.id}-v`, name: pet.name, text: t("medical.flags.vaccineOverdue"), tone: AMBER });
    if (flags.allergies) out.push({ id: `${pet.id}-a`, name: pet.name, text: t("medical.flags.allergies", { text: flags.allergies }), tone: AMBER });
    return out;
  })
);
</script>
