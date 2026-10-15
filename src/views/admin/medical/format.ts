import type { VaccineKind } from "@/types/medical";
import type { VisitStatus } from "@/types/medicalVisit";
import type { BookState } from "@/types/vaccination";

export { dateTime, money } from "@/views/admin/pos/format";
export { addDays, dateKeyOf, timeOf, todayKey, toIso } from "@/views/admin/schedule/format";

/** Badge colours of the kind of a vaccine type. */
export const VACCINE_KIND_TONE: Record<VaccineKind, string> = {
  vaccine: "bg-sky-100 text-sky-800",
  deworm: "bg-amber-100 text-amber-800",
  other: "bg-slate-200 text-slate-700",
};

/** Badge colours of a visit's status. */
export const VISIT_TONE: Record<VisitStatus, string> = {
  scheduled: "bg-sky-100 text-sky-800",
  waiting: "bg-amber-100 text-amber-800",
  in_progress: "bg-emerald-100 text-emerald-800",
  done: "bg-violet-100 text-violet-800",
  paid: "bg-slate-200 text-slate-700",
  cancelled: "bg-red-100 text-red-700",
  no_show: "bg-red-100 text-red-700",
};

/** Whole minutes since an ISO time; 0 when there is none or it lies ahead. */
export const minutesSince = (iso: string | null, now: number = Date.now()): number =>
  iso ? Math.max(Math.floor((now - Date.parse(iso)) / 60_000), 0) : 0;

/** Badge colours of the state of a vaccine in the e-book. */
export const BOOK_STATE_TONE: Record<BookState, string> = {
  ok: "bg-emerald-100 text-emerald-800",
  due_soon: "bg-amber-100 text-amber-800",
  overdue: "bg-red-100 text-red-700",
};
