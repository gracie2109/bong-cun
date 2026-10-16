import { computed, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { useSaveWeightBrackets, useWeightBrackets } from "@/queries/weightBrackets";
import { checkBrackets, type WeightBracketInput } from "@/repositories/weightBrackets";

/** One editable bracket. Text fields hold what was typed; numbers are parsed on save. */
export type BracketRow = { key: number; id?: string; label: string; min: string; max: string };

/** Share of the ruler left for the open-ended bracket beyond the largest finite bound. */
const OPEN_ENDED_SLICE = 1.25;

/** The weight brackets of a species being edited: rows, what is wrong with them, and saving. */
export const useBracketRows = (speciesId: () => string) => {
  const { t } = useI18n();
  const bracketsQuery = useWeightBrackets(computed(() => speciesId()));
  const saveMutation = useSaveWeightBrackets();

  const rows = ref<BracketRow[]>([]);
  const confirmOpen = ref(false);
  let nextKey = 1;

  const savedRows = (): BracketRow[] =>
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
  watch(() => [speciesId(), bracketsQuery.data.value], resetRows, { immediate: true });

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

  /** Saved brackets that are no longer in the rows. */
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
    const scale = (finiteMax || 1) * (hasOpen ? OPEN_ENDED_SLICE : 1);
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

  const save = async () => {
    confirmOpen.value = false;
    try {
      await saveMutation.mutateAsync({ speciesId: speciesId(), rows: parsed.value });
    } catch {
      // the mutation already showed the failure toast; keep the edits
    }
  };

  /** Saving that drops brackets asks first. */
  const requestSave = () => {
    if (removedCount.value > 0) confirmOpen.value = true;
    else void save();
  };

  return {
    isPending: bracketsQuery.isPending,
    rows,
    confirmOpen,
    issueTexts,
    removedCount,
    dirty,
    canSave,
    segments,
    addRow,
    removeRow,
    resetRows,
    requestSave,
    save,
  };
};
