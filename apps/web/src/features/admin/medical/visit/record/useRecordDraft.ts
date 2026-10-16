import { computed, ref, watch, type Ref } from "vue";
import { useSaveRecord, useSignVisit } from "@/queries/medicalVisits";
import type { MedicalVisitDetail } from "@bongcun/core/medical";
import { canSignDraft, draftFromVisit, toRecordInput, type RecordDraft } from "./recordDraft";

/** The record form of one visit: its draft, saving, and the signature that locks it. */
export const useRecordDraft = (visit: Ref<MedicalVisitDetail>, canEdit: Ref<boolean>) => {
  const draft = ref<RecordDraft>(draftFromVisit(visit.value));

  // A refetch of an unchanged visit must not wipe what the vet is typing: reload only when the
  // visit changes or its record was saved elsewhere (a different id or a new signature).
  watch(
    () => [visit.value.id, visit.value.signedAt, visit.value.status],
    () => {
      draft.value = draftFromVisit(visit.value);
    }
  );

  const readonly = computed(() => !canEdit.value);
  const signable = computed(() => canEdit.value && canSignDraft(draft.value));

  const saveMutation = useSaveRecord();
  const signMutation = useSignVisit();
  const busy = computed(() => saveMutation.isPending.value || signMutation.isPending.value);

  const save = async (): Promise<boolean> => {
    try {
      await saveMutation.mutateAsync({ id: visit.value.id, record: toRecordInput(draft.value) });
      return true;
    } catch {
      return false;
    }
  };

  /** Saves the form, then signs: nothing is signed that was not stored first. */
  const sign = async () => {
    if (!(await save())) return;
    try {
      await signMutation.mutateAsync(visit.value.id);
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return { draft, readonly, signable, busy, save, sign };
};
