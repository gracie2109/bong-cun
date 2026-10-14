import { computed, reactive, ref, watch } from "vue";
import { useMyProfile, useSaveMyProfile } from "@/queries/account";
import { emptyProfileForm, isProfileChanged, profileErrors, profileToForm } from "@/utils/account/profile";

/** The profile form: loads the saved profile, validates, saves. */
export const useProfileForm = () => {
  const query = useMyProfile();
  const mutation = useSaveMyProfile();

  const form = reactive(emptyProfileForm());
  const submitted = ref(false);
  const errors = computed(() => profileErrors(form));
  const changed = computed(() => isProfileChanged(form, query.data.value));

  // Fill the form when the profile arrives (and again after a save returns the stored values).
  watch(
    () => query.data.value,
    (profile) => {
      if (profile) Object.assign(form, profileToForm(profile));
    },
    { immediate: true }
  );

  const submit = async () => {
    submitted.value = true;
    if (Object.keys(errors.value).length > 0) return;
    try {
      await mutation.mutateAsync({ ...form });
      submitted.value = false;
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return {
    form,
    errors,
    submitted,
    changed,
    email: computed(() => query.data.value?.email ?? ""),
    loading: query.isLoading,
    failed: query.isError,
    retry: () => void query.refetch(),
    saving: mutation.isPending,
    submit,
  };
};
