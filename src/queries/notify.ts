import i18n from "@/i18n";
import { sendMessageToast } from "@/lib/utils";
import {
  hasPgCode,
  PG_FOREIGN_KEY_VIOLATION,
  PG_INSUFFICIENT_PRIVILEGE,
  PG_UNIQUE_VIOLATION,
} from "@/repositories/shared";
import { UserFunctionError } from "@/repositories/users";
import type { RestfullMethod } from "@/types";

/** Failure toast for a mutation, turning database error codes into readable messages. */
export const notifyFailure = (method: RestfullMethod, error: unknown, subject = "") => {
  const t = i18n.global.t;
  let message = (error as { message?: string } | null)?.message ?? "";

  if (error instanceof UserFunctionError) {
    message = error.message;
  } else if (hasPgCode(error, PG_UNIQUE_VIOLATION)) {
    message = t("common.dataExisted", { field: subject });
  } else if (hasPgCode(error, PG_FOREIGN_KEY_VIOLATION)) {
    message = t("common.inUse");
  } else if (hasPgCode(error, PG_INSUFFICIENT_PRIVILEGE)) {
    message = t("common.noPermission");
  }

  sendMessageToast("fail", method, "error", message);
};

export const notifySuccess = (method: RestfullMethod) =>
  sendMessageToast("success", method, "success");
