<template>
  <section class="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-violet-200 bg-violet-50 px-4 py-3 text-sm text-violet-900">
    <p>{{ $t("boarding.detail.inpatientNotice") }}</p>
    <div v-if="canViewMedical" class="flex flex-wrap gap-2">
      <Button size="sm" variant="outline" as-child>
        <router-link :to="{ name: 'medicalWard' }">{{ $t("boarding.detail.openWard") }}</router-link>
      </Button>
      <Button v-if="stay.visitId" size="sm" variant="outline" as-child>
        <router-link :to="{ name: 'medicalVisitDetail', params: { visitId: stay.visitId } }">
          {{ $t("boarding.detail.openVisit", { code: stay.visitCode ?? "" }) }}
        </router-link>
      </Button>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Button } from "@/components/ui/button";
import { useAuthStore } from "@/stores";
import type { BoardingStay } from "@bongcun/core/boarding";

defineProps<{ stay: BoardingStay }>();
const auth = useAuthStore();
const canViewMedical = computed(() => auth.can("medical", "VIEW"));
</script>
