<template>
  <div class="space-y-4">
    <div>
      <h3 class="font-semibold">{{ $t("petCare.species.bracketsTitle") }}</h3>
      <p class="text-sm text-muted-foreground">{{ $t("petCare.species.bracketsHint") }}</p>
    </div>

    <Skeleton v-if="bracketsQuery.isPending.value" class="h-40 w-full" />
    <template v-else>
      <!-- Ruler: each bracket drawn in proportion, gaps stay empty. -->
      <div v-if="segments.length" class="relative h-8 overflow-hidden rounded-lg bg-muted">
        <div
          v-for="segment in segments"
          :key="segment.key"
          class="absolute top-0 flex h-full items-center justify-center overflow-hidden border-r border-white bg-primary/80 px-1 text-[11px] font-medium text-primary-foreground"
          :style="{ left: `${segment.left}%`, width: `${segment.width}%` }"
          :title="segment.label"
        >
          <span class="truncate">{{ segment.label }}</span>
        </div>
      </div>

      <div class="overflow-x-auto rounded-xl border">
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-muted/40 text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-3 py-2 font-semibold">{{ $t("petCare.species.colLabel") }}</th>
              <th class="w-28 px-3 py-2 font-semibold">{{ $t("petCare.species.colFrom") }}</th>
              <th class="w-28 px-3 py-2 font-semibold">{{ $t("petCare.species.colTo") }}</th>
              <th class="w-12 px-3 py-2"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in rows" :key="row.key" class="border-t">
              <td class="px-3 py-2"><Input v-model="row.label" :readonly="!canUpdate" /></td>
              <td class="px-3 py-2">
                <Input v-model="row.min" :readonly="!canUpdate" type="number" min="0" step="0.1" inputmode="decimal" />
              </td>
              <td class="px-3 py-2">
                <Input
                  v-model="row.max"
                  :readonly="!canUpdate"
                  type="number"
                  min="0"
                  step="0.1"
                  inputmode="decimal"
                  :placeholder="$t('petCare.species.unlimited')"
                />
              </td>
              <td class="px-3 py-2 text-right">
                <Button
                  v-if="canUpdate"
                  type="button"
                  variant="ghost"
                  size="icon"
                  class="size-8"
                  :aria-label="$t('petCare.species.removeBracket')"
                  @click="removeRow(row.key)"
                >
                  <Trash2 class="size-4" />
                </Button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <ul v-if="issueTexts.length" class="space-y-1">
        <li
          v-for="issue in issueTexts"
          :key="issue.text"
          class="flex items-start gap-2 rounded-lg px-3 py-2 text-sm"
          :class="issue.blocking ? 'bg-red-50 text-red-700' : 'bg-amber-50 text-amber-700'"
        >
          <TriangleAlert class="mt-0.5 size-4 shrink-0" />
          {{ issue.text }}
        </li>
      </ul>
      <p v-if="removedCount > 0" class="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
        {{ $t("petCare.species.removeWarning", { n: removedCount }) }}
      </p>

      <div v-if="canUpdate" class="flex flex-wrap items-center justify-between gap-2">
        <Button type="button" variant="outline" @click="addRow">
          <Plus class="mr-2 size-4" />
          {{ $t("petCare.species.addBracket") }}
        </Button>
        <div class="flex gap-2">
          <Button type="button" variant="ghost" :disabled="!dirty" @click="resetRows">
            {{ $t("petCare.species.resetBrackets") }}
          </Button>
          <Button type="button" :disabled="!canSave" @click="requestSave">
            {{ $t("petCare.species.saveBrackets") }}
          </Button>
        </div>
      </div>
    </template>

    <ConfirmDialog
      :open="confirmOpen"
      :title="$t('petCare.species.confirmSaveTitle', { n: removedCount })"
      :desc="$t('petCare.species.confirmSaveDesc')"
      :ok-btn="$t('petCare.common.confirm')"
      @cancel="confirmOpen = false"
      @open-change="confirmOpen = false"
      @handle-ok="save"
    />
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { Plus, Trash2, TriangleAlert } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { usePermission } from "@/composables/usePermission";
import { useSaveWeightBrackets, useWeightBrackets } from "@/queries/weightBrackets";
import { checkBrackets, type WeightBracketInput } from "@/repositories/weightBrackets";

type Row = { key: number; id?: string; label: string; min: string; max: string };

const props = defineProps<{ speciesId: string }>();

const { t } = useI18n();
const speciesId = computed(() => props.speciesId);
const bracketsQuery = useWeightBrackets(speciesId);
const saveMutation = useSaveWeightBrackets();
const { canUpdate } = usePermission("petServices");

const rows = ref<Row[]>([]);
const confirmOpen = ref(false);
let nextKey = 1;

const savedRows = (): Row[] =>
  (bracketsQuery.data.value ?? []).map((bracket) => ({
    key: nextKey++,
    id: bracket.id,
    label: bracket.label,
    min: String(bracket.minKg),
    max: bracket.maxKg === null ? "" : String(bracket.maxKg),
  }));

const resetRows = () => {
  rows.value = savedRows();
};

// Reload the editor whenever another species is picked or the saved data changes.
watch(() => [props.speciesId, bracketsQuery.data.value], resetRows, { immediate: true });

const parsed = computed<WeightBracketInput[]>(() =>
  rows.value.map((row) => ({
    id: row.id,
    label: row.label.trim(),
    minKg: Number(row.min === "" ? NaN : row.min),
    maxKg: row.max === "" ? null : Number(row.max),
  }))
);

const incomplete = computed(() =>
  parsed.value.some(
    (row) =>
      !row.label || Number.isNaN(row.minKg) || row.minKg < 0 || (row.maxKg !== null && Number.isNaN(row.maxKg))
  )
);

const issues = computed(() => (incomplete.value ? [] : checkBrackets(parsed.value)));
const issueTexts = computed(() =>
  issues.value.map((issue) => {
    if (issue.type === "overlap")
      return { blocking: true, text: t("petCare.species.issueOverlap", { first: issue.first, second: issue.second }) };
    if (issue.type === "invalid")
      return { blocking: true, text: t("petCare.species.issueInvalid", { label: issue.label }) };
    return { blocking: false, text: t("petCare.species.issueGap", { from: issue.fromKg, to: issue.toKg }) };
  })
);
const hasBlocking = computed(() => issues.value.some((issue) => issue.type !== "gap"));

const removedCount = computed(() => {
  const kept = new Set(rows.value.map((row) => row.id).filter(Boolean));
  return (bracketsQuery.data.value ?? []).filter((bracket) => !kept.has(bracket.id)).length;
});

const dirty = computed(() => {
  const saved = bracketsQuery.data.value ?? [];
  if (saved.length !== rows.value.length) return true;
  return rows.value.some((row, index) => {
    const original = saved[index];
    return (
      !original ||
      row.id !== original.id ||
      row.label !== original.label ||
      row.min !== String(original.minKg) ||
      row.max !== (original.maxKg === null ? "" : String(original.maxKg))
    );
  });
});

const canSave = computed(
  () => dirty.value && rows.value.length > 0 && !incomplete.value && !hasBlocking.value && !saveMutation.isPending.value
);

// Ruler scale: up to the largest finite bound, with the open-ended bracket drawn over a final slice.
const segments = computed(() => {
  if (incomplete.value || rows.value.length === 0) return [];
  const finiteMax = Math.max(...parsed.value.map((row) => row.maxKg ?? row.minKg));
  const hasOpen = parsed.value.some((row) => row.maxKg === null);
  const scale = (finiteMax || 1) * (hasOpen ? 1.25 : 1);
  return parsed.value.map((row, index) => {
    const end = row.maxKg ?? scale;
    return {
      key: rows.value[index].key,
      label: row.label,
      left: Math.min(100, (row.minKg / scale) * 100),
      width: Math.max(0, Math.min(100, ((end - row.minKg) / scale) * 100)),
    };
  });
});

const addRow = () => {
  const last = [...parsed.value].sort((a, b) => b.minKg - a.minKg)[0];
  rows.value.push({
    key: nextKey++,
    label: t("petCare.species.newBracket"),
    min: last && last.maxKg !== null && !Number.isNaN(last.maxKg) ? String(last.maxKg) : "",
    max: "",
  });
};

const removeRow = (key: number) => {
  rows.value = rows.value.filter((row) => row.key !== key);
};

const requestSave = () => {
  if (removedCount.value > 0) confirmOpen.value = true;
  else void save();
};

const save = async () => {
  confirmOpen.value = false;
  try {
    await saveMutation.mutateAsync({ speciesId: props.speciesId, rows: parsed.value });
  } catch {
    // the mutation already showed the failure toast; keep the edits
  }
};
</script>
