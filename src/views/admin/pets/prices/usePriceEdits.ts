import { computed, ref, watch, type Ref } from "vue";
import { useSaveServicePrices } from "@/queries/servicePrices";
import type { WeightBracket } from "@/repositories/weightBrackets";
import { SHARED } from "./usePriceCatalog";

const cellKey = (serviceId: string, bracketId: string) => `${serviceId}:${bracketId}`;

type Catalog = {
  speciesId: Ref<string | undefined>;
  branchId: Ref<string | null>;
  scope: Ref<string>;
  brackets: Ref<WeightBracket[]>;
  saved: Ref<Map<string, number>>;
  shared: Ref<Map<string, number>>;
};

/** Price edits not saved yet, keyed by "serviceId:bracketId"; an empty text clears the cell. */
export const usePriceEdits = ({ speciesId, branchId, scope, brackets, saved, shared }: Catalog) => {
  const edits = ref(new Map<string, string>());
  const dirtyCount = computed(() => edits.value.size);
  const fillStart = ref("");
  const fillStep = ref("");
  const saveMutation = useSaveServicePrices();

  const savedText = (serviceId: string, bracketId: string): string => {
    const value = saved.value.get(cellKey(serviceId, bracketId));
    return value === undefined ? "" : String(value);
  };
  const cellValue = (serviceId: string, bracketId: string): string =>
    edits.value.get(cellKey(serviceId, bracketId)) ?? savedText(serviceId, bracketId);
  const isEdited = (serviceId: string, bracketId: string) => edits.value.has(cellKey(serviceId, bracketId));
  /** The shared price a branch cell falls back to, shown as a hint. */
  const placeholderOf = (serviceId: string, bracketId: string): string => {
    const inherited = scope.value === SHARED ? undefined : shared.value.get(cellKey(serviceId, bracketId));
    return inherited === undefined ? "" : String(inherited);
  };

  const setCell = (serviceId: string, bracketId: string, value: string) => {
    const next = new Map(edits.value);
    if (value === savedText(serviceId, bracketId)) next.delete(cellKey(serviceId, bracketId));
    else next.set(cellKey(serviceId, bracketId), value);
    edits.value = next;
  };

  /** Fills a row with the start price plus the step for each bracket in turn. */
  const fillRow = (serviceId: string) => {
    if (fillStart.value === "") return;
    const start = Number(fillStart.value);
    const step = Number(fillStep.value || 0);
    brackets.value.forEach((bracket, index) => setCell(serviceId, bracket.id, String(start + step * index)));
  };
  const clearRow = (serviceId: string) => {
    brackets.value.forEach((bracket) => setCell(serviceId, bracket.id, ""));
  };

  const discard = () => {
    edits.value = new Map();
  };

  // Edits belong to one species and scope: drop them when either changes.
  watch([speciesId, scope], discard);

  const saveAll = async () => {
    if (!speciesId.value) return;
    const touched = new Set([...edits.value.keys()].map((key) => key.split(":")[0]));
    try {
      for (const serviceId of touched) {
        const rows = brackets.value
          .map((bracket) => ({ bracketId: bracket.id, price: cellValue(serviceId, bracket.id) }))
          .filter((row) => row.price !== "")
          .map((row) => ({ bracketId: row.bracketId, price: Number(row.price) }));
        await saveMutation.mutateAsync({
          speciesId: speciesId.value,
          serviceId,
          branchId: branchId.value,
          rows,
        });
      }
      discard();
    } catch {
      // the mutation already showed the failure toast; keep the edits
    }
  };

  return {
    dirtyCount,
    fillStart,
    fillStep,
    saving: saveMutation.isPending,
    cellValue,
    isEdited,
    placeholderOf,
    setCell,
    fillRow,
    clearRow,
    discard,
    saveAll,
  };
};
