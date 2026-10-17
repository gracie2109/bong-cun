import { computed, ref, watch, type Ref } from "vue";
import { todayInput } from "../format";
import { useMarkPetDeceased, usePetDeceasedPreview } from "@/queries/pets";

/** State of the "mark as deceased" dialog: the preview of what gets cancelled, the date and the note. */
export const useMarkDeceased = (petId: Ref<string>, open: Ref<boolean>, birthDate: Ref<string | null>) => {
  const preview = usePetDeceasedPreview(petId, open);
  const marking = useMarkPetDeceased();

  const deceasedOn = ref(todayInput());
  const note = ref("");
  watch(open, (isOpen) => {
    if (!isOpen) return;
    deceasedOn.value = todayInput();
    note.value = "";
  });

  const data = computed(() => preview.data.value ?? null);
  const blocked = computed(() => (data.value?.blocking.length ?? 0) > 0);
  const dateInvalid = computed(
    () => !deceasedOn.value || deceasedOn.value > todayInput() || (!!birthDate.value && deceasedOn.value < birthDate.value)
  );
  const cancelCount = computed(
    () => (data.value?.appointments.length ?? 0) + (data.value?.stays.length ?? 0) + (data.value?.visits.length ?? 0)
  );
  const canSubmit = computed(() => !!data.value && !blocked.value && !dateInvalid.value);

  /** Returns true when the pet was marked, so the dialog can close. */
  const submit = async (): Promise<boolean> => {
    if (!canSubmit.value) return false;
    try {
      await marking.mutateAsync({ id: petId.value, input: { deceasedOn: deceasedOn.value, note: note.value } });
      return true;
    } catch {
      return false; // the mutation already showed the failure toast
    }
  };

  return { preview, data, blocked, dateInvalid, cancelCount, canSubmit, deceasedOn, note, busy: marking.isPending, submit };
};
