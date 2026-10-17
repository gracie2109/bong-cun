<template>
  <div class="space-y-2">
    <Label>{{ $t("medical.record.diagnoses") }}</Label>
    <ul v-if="draft.diagnoses.length" class="flex flex-wrap gap-2">
      <li
        v-for="(item, index) in draft.diagnoses"
        :key="`${item.termId ?? item.name}-${index}`"
        class="flex items-center gap-1 rounded-full border px-3 py-1 text-sm"
        :class="item.isContagious && 'border-fuchsia-300 bg-fuchsia-50'"
      >
        {{ item.name }}
        <span v-if="item.isContagious" class="text-[10px] font-semibold text-fuchsia-800">{{ $t("medical.flags.contagious") }}</span>
        <button v-if="!readonly" type="button" class="text-muted-foreground hover:text-red-600" :aria-label="$t('medical.record.removeDiagnosis')" @click="remove(index)">
          <X class="size-3.5" />
        </button>
      </li>
    </ul>
    <p v-else class="text-sm text-muted-foreground">{{ $t("medical.record.noDiagnosis") }}</p>

    <div v-if="!readonly" class="relative">
      <Input v-model="search" :placeholder="$t('medical.record.diagnosisSearch')" @keydown.enter.prevent="addFreeText" />
      <ul v-if="search.trim()" class="absolute z-10 mt-1 max-h-56 w-full overflow-auto rounded-lg border bg-white p-1 shadow-lg">
        <li v-for="term in terms" :key="term.id">
          <button type="button" class="flex w-full items-center justify-between rounded-md px-3 py-2 text-left text-sm hover:bg-muted" @click="addTerm(term)">
            {{ term.name }}
            <span v-if="term.isContagious" class="text-[10px] font-semibold text-fuchsia-800">{{ $t("medical.flags.contagious") }}</span>
          </button>
        </li>
        <li>
          <button type="button" class="w-full rounded-md px-3 py-2 text-left text-sm text-primary hover:bg-muted" @click="addFreeText">
            {{ $t("medical.record.addFreeText", { name: search.trim() }) }}
          </button>
        </li>
      </ul>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { refDebounced } from "@vueuse/core";
import { X } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SEARCH_DEBOUNCE_MS } from "@/lib/listing";
import { useDiagnosisTerms } from "@/features/admin/medical/queries/medical";
import type { DiagnosisTerm } from "@bongcun/core/medical";
import type { RecordDraft } from "./recordDraft";

defineProps<{ readonly: boolean }>();
const draft = defineModel<RecordDraft>("draft", { required: true });

const search = ref("");
const debounced = refDebounced(search, SEARCH_DEBOUNCE_MS);
const termsQuery = useDiagnosisTerms(
  { pageIndex: 1, pageSize: 8 },
  computed(() => ({ search: debounced.value.trim(), activeOnly: true }))
);
const terms = computed(() => (debounced.value.trim() ? termsQuery.data.value?.rows ?? [] : []));

const has = (name: string) => draft.value.diagnoses.some((item) => item.name.toLowerCase() === name.toLowerCase());

const addTerm = (term: DiagnosisTerm) => {
  if (!has(term.name)) draft.value.diagnoses.push({ termId: term.id, name: term.name, isContagious: term.isContagious, note: "" });
  search.value = "";
};

const addFreeText = () => {
  const name = search.value.trim();
  if (name && !has(name)) draft.value.diagnoses.push({ termId: null, name, isContagious: false, note: "" });
  search.value = "";
};

const remove = (index: number) => draft.value.diagnoses.splice(index, 1);
</script>
