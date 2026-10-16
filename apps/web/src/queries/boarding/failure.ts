import i18n from "@/i18n";
import { sendMessageToast } from "@/lib/utils";
import { boardingErrorDetail, boardingErrorHint } from "@bongcun/supabase/boarding";
import type { RestfullMethod } from "@/types";
import { notifyFailure } from "../notify";

/** Failure toast that turns the boarding rules (duplicate code, bad hours...) into text. */
export const notifyBoardingFailure = (method: RestfullMethod, error: unknown) => {
  const hint = boardingErrorHint(error);
  if (hint) {
    sendMessageToast("fail", method, "error", i18n.global.t(`boarding.errors.${hint}`, { name: boardingErrorDetail(error) }));
  }
  else notifyFailure(method, error);
};
