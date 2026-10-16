import { ref, unref, type MaybeRef } from "vue";
import { useQueryClient } from "@tanstack/vue-query";
import { toast } from "vue-sonner";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { invalidateCatalog } from "@/queries/invalidate";
import { notifyFailure, notifySuccess } from "@/queries/notify";
import { removePetPhoto, setPetPhoto } from "@bongcun/supabase/pets";
import { photoProblemKey, preparePetPhoto } from "./preparePetPhoto";

/** Changing or removing one pet's photo from the admin screens. */
export const usePetPhoto = (petId: MaybeRef<string>) => {
  const queryClient = useQueryClient();
  const uploading = ref(false);

  const run = async (job: () => Promise<void>) => {
    uploading.value = true;
    try {
      await job();
      await invalidateCatalog(queryClient);
      notifySuccess("update");
    } catch (error) {
      notifyFailure("update", error);
    } finally {
      uploading.value = false;
    }
  };

  /** Shrinks the chosen picture, checks it fits the bucket's rules, then uploads it. */
  const change = async (original: File) => {
    uploading.value = true;
    const prepared = await preparePetPhoto(original);
    uploading.value = false;
    if (prepared.problem) {
      toast.error(i18n.global.t(photoProblemKey(prepared.problem)));
      return;
    }
    const file = prepared.file;
    await run(async () => {
      await setPetPhoto(supabaseClient(), unref(petId), file);
    });
  };

  const remove = () => run(() => removePetPhoto(supabaseClient(), unref(petId)));

  return { uploading, change, remove };
};
