import { useQueryClient } from "@tanstack/vue-query";
import { toast } from "vue-sonner";
import i18n from "@/i18n";
import { supabaseClient } from "@/lib/supabase";
import { invalidateCatalog } from "@/queries/invalidate";
import { setPetPhoto } from "@bongcun/supabase/pets";
import { photoProblemKey, preparePetPhoto } from "./preparePetPhoto";

/**
 * Saves the picture chosen while registering a pet, after the pet exists. A failure never undoes the
 * registration: the pet is kept and the staff member is told the photo was not saved.
 */
export const useRegisterPhoto = () => {
  const queryClient = useQueryClient();

  return async (petId: string, original: File): Promise<void> => {
    try {
      const prepared = await preparePetPhoto(original);
      if (prepared.problem) throw new Error(i18n.global.t(photoProblemKey(prepared.problem)));
      await setPetPhoto(supabaseClient(), petId, prepared.file);
      await invalidateCatalog(queryClient);
    } catch {
      toast.warning(i18n.global.t("petCare.pets.photo.createdWithoutPhoto"));
    }
  };
};
