import i18n from "@/i18n";
import { sendMessageToast } from "@/lib/utils";
import { attendanceErrorHint } from "@bongcun/supabase/attendance";
import type { RestfullMethod } from "@/types";
import { notifyFailure } from "@/queries/notify";

/** Failure toast that turns the attendance rules (overlap, name taken...) into text. */
export const notifyAttendanceFailure = (method: RestfullMethod, error: unknown) => {
  const hint = attendanceErrorHint(error);
  if (hint) sendMessageToast("fail", method, "error", i18n.global.t(`attendance.errors.${hint}`));
  else notifyFailure(method, error);
};
