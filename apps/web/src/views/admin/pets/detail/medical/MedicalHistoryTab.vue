<template>
  <div class="space-y-3">
    <p v-if="historyQuery.isPending.value" class="py-6 text-center text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <p v-else-if="rows.length === 0" class="py-10 text-center text-sm text-muted-foreground">{{ $t("medical.side.noHistory") }}</p>
    <ul class="space-y-2">
      <li v-for="item in rows" :key="item.id">
        <router-link
          :to="{ name: 'medicalVisitDetail', params: { visitId: item.id } }"
          class="block rounded-lg border px-4 py-3 text-sm hover:border-primary/50"
        >
          <div class="flex flex-wrap items-center justify-between gap-2">
            <p class="font-semibold">{{ item.diagnosesText ?? item.reason ?? item.code }}</p>
            <span class="rounded-full px-2 py-0.5 text-[10px] font-semibold" :class="VISIT_TONE[item.status]">{{ $t(`medical.status.${item.status}`) }}</span>
          </div>
          <p class="text-xs text-muted-foreground">
            {{ dateTime(item.checkedInAt ?? item.createdAt) }} · {{ item.branchName }}<template v-if="item.vetName"> · {{ item.vetName }}</template>
            <template v-if="item.outcome"> · {{ $t(`medical.outcome.${item.outcome}`) }}</template>
          </p>
        </router-link>
      </li>
    </ul>
    <div v-if="pageCount > 1" class="flex items-center justify-end gap-2">
      <Button variant="outline" size="sm" :disabled="page.pageIndex <= 1" @click="page.pageIndex--">{{ $t("petCare.common.back") }}</Button>
      <span class="text-xs text-muted-foreground">{{ page.pageIndex }} / {{ pageCount }}</span>
      <Button variant="outline" size="sm" :disabled="page.pageIndex >= pageCount" @click="page.pageIndex++">{{ $t("medical.side.next") }}</Button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, reactive } from "vue";
import { Button } from "@/components/ui/button";
import { usePetMedicalHistory } from "@/queries/medicalVisits";
import { dateTime, VISIT_TONE } from "@/views/admin/medical/format";

const props = defineProps<{ petId: string }>();

const page = reactive({ pageIndex: 1, pageSize: 10 });
const historyQuery = usePetMedicalHistory(computed(() => props.petId), page);
const rows = computed(() => historyQuery.data.value?.rows ?? []);
const pageCount = computed(() => Math.max(Math.ceil((historyQuery.data.value?.total ?? 0) / page.pageSize), 1));
</script>
