import i18n from "@/i18n";
import { sendMessageToast } from "@/lib/utils";
import { toAppError } from "@bongcun/supabase/shared";
import { UserFunctionError } from "@/repositories/users";
import type { RestfullMethod } from "@/types";

/** Failure toast for a mutation, turning database error codes into readable messages. */
export const notifyFailure = (method: RestfullMethod, error: unknown, subject = "") => {
  const t = i18n.global.t;
  let message = (error as { message?: string } | null)?.message ?? "";

  if (error instanceof UserFunctionError) {
    message = error.message;
  } else {
    const code = toAppError(error)?.code;
    if (code === "conflict") message = t("common.dataExisted", { field: subject });
    else if (code === "in_use") message = t("common.inUse");
    else if (code === "forbidden") message = t("common.noPermission");
  }

  sendMessageToast("fail", method, "error", message);
};

export const notifySuccess = (method: RestfullMethod) =>
  sendMessageToast("success", method, "success");
