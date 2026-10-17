import { useMutation, useQueryClient } from "@tanstack/vue-query";
import type { RestfullMethod } from "@/types";
import { boardingKeys } from "@/queries/keys";
import { notifySuccess } from "@/queries/notify";
import { notifyBoardingFailure } from "@/features/admin/boarding/queries/failure";

/** A stay changes under all of the board, the list and the detail, so every action refreshes them. */
export const useBoardingAction = <Variables, Result = void>(
  action: (variables: Variables) => Promise<Result>,
  method: RestfullMethod = "update"
) => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: action,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: boardingKeys.all });
      notifySuccess(method);
    },
    onError: (error) => notifyBoardingFailure(method, error),
  });
};
