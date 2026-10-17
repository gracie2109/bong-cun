<template>
  <div class="space-y-3 text-sm">
    <div v-if="blocked" class="rounded-lg border border-red-200 bg-red-50 p-3 text-red-800">
      <p class="font-semibold">{{ $t("petCare.pets.deceased.blocked") }}</p>
      <ul class="mt-1 list-disc pl-5">
        <li v-for="item in preview.blocking" :key="item.id">
          {{ $t(`petCare.pets.deceased.blockedType.${item.type}`) }} {{ item.code }}
        </li>
      </ul>
    </div>

    <template v-else>
      <p v-if="!cancelCount" class="text-muted-foreground">{{ $t("petCare.pets.deceased.nothingBooked") }}</p>
      <div v-for="group in groups" :key="group.key">
        <template v-if="group.rows.length">
          <p class="font-medium">{{ $t(`petCare.pets.deceased.cancel.${group.key}`, { n: group.rows.length }) }}</p>
          <ul class="mt-1 space-y-0.5 text-muted-foreground">
            <li v-for="row in group.rows" :key="row.id">
              {{ row.code }} · {{ formatDateTime(row.startAt) }} · {{ row.branchName }}
              <span v-if="!row.whole" class="text-xs">({{ $t("petCare.pets.deceased.partOnly") }})</span>
            </li>
          </ul>
        </template>
      </div>
    </template>

    <div v-if="preview.open.length" class="rounded-lg border border-amber-200 bg-amber-50 p-3 text-amber-900">
      <p class="font-semibold">{{ $t("petCare.pets.deceased.openWork") }}</p>
      <ul class="mt-1 list-disc pl-5">
        <li v-for="item in preview.open" :key="item.id">
          {{ $t(`petCare.pets.deceased.openType.${item.type}`) }} {{ item.code }}
        </li>
      </ul>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { DeceasedPreview } from "@bongcun/supabase/pets";
import { formatDateTime } from "../format";

const props = defineProps<{ preview: DeceasedPreview; blocked: boolean; cancelCount: number }>();

const groups = computed(() => [
  { key: "appointments", rows: props.preview.appointments },
  { key: "stays", rows: props.preview.stays },
  { key: "visits", rows: props.preview.visits },
]);
</script>
