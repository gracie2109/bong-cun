import { useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  addMedicalAttachment,
  listMedicalAttachments,
  removeMedicalAttachment,
  signedAttachmentUrl,
  type AttachmentInput,
} from "@/repositories/medical";
import { medicalKeys } from "./keys";
import { notifyMedicalFailure } from "./medical";
import { notifySuccess } from "./notify";

export const useMedicalAttachments = (visitId: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => medicalKeys.attachments(unref(visitId))),
    queryFn: () => listMedicalAttachments(supabaseClient(), unref(visitId)),
    enabled: computed(() => !!unref(visitId)),
  });

export const useAddAttachment = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: AttachmentInput) => addMedicalAttachment(supabaseClient(), input),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: medicalKeys.all });
      notifySuccess("create");
    },
    onError: (error) => notifyMedicalFailure("create", error),
  });
};

export const useRemoveAttachment = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => removeMedicalAttachment(supabaseClient(), id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: medicalKeys.all });
      notifySuccess("delete");
    },
    onError: (error) => notifyMedicalFailure("delete", error),
  });
};

/** Opens a file in a new tab through a ten-minute signed link. */
export const openAttachment = async (path: string): Promise<void> => {
  const url = await signedAttachmentUrl(supabaseClient(), path);
  window.open(url, "_blank", "noopener");
};
