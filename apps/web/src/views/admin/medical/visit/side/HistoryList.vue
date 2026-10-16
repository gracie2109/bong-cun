<template>
  <section class="space-y-2">
    <h4 class="text-sm font-semibold">{{ $t("medical.side.history") }}</h4>
    <p v-if="historyQuery.isPending.value" class="text-xs text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <p v-else-if="others.length === 0" class="text-xs text-muted-foreground">{{ $t("medical.side.noHistory") }}</p>
    <ul class="space-y-2">
      <li v-for="item in others" :key="item.id">
        <router-link
          :to="{ name: 'medicalVisitDetail', params: { visitId: item.id } }"
          class="block rounded-lg border px-3 py-2 text-sm hover:border-primary/50"
        >
          <p class="font-medium">{{ item.diagnosesText ?? item.reason ?? item.code }}</p>
          <p class="text-xs text-muted-foreground">{{ dateTime(item.checkedInAt ?? item.createdAt) }} · {{ item.branchName }}</p>
        </router-link>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { computed, reactive } from "vue";
import { usePetMedicalHistory } from "@/queries/medicalVisits";
import { dateTime } from "../../format";

const props = defineProps<{ petId: string; currentVisitId: string }>();

const page = reactive({ pageIndex: 1, pageSize: 10 });
const historyQuery = usePetMedicalHistory(computed(() => props.petId), page);
const others = computed(() => (historyQuery.data.value?.rows ?? []).filter((item) => item.id !== props.currentVisitId));
</script>
