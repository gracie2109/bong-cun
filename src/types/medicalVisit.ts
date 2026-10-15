// Medical visits: the queue, the visit list and the record of one visit.
export type VisitStatus = "scheduled" | "waiting" | "in_progress" | "done" | "paid" | "cancelled" | "no_show";
export const VISIT_STATUSES: readonly VisitStatus[] = ["scheduled", "waiting", "in_progress", "done", "paid", "cancelled", "no_show"];

export type VisitPriority = "normal" | "urgent";
export type VisitOutcome = "home" | "recheck" | "inpatient" | "referred" | "deceased";
export const VISIT_OUTCOMES: readonly VisitOutcome[] = ["home", "recheck", "inpatient", "referred", "deceased"];
export type VisitSource = "counter" | "phone" | "recheck" | "web";

/** A visit as the queue, the list and the pet history show it. */
export type MedicalVisit = {
  id: string;
  code: string;
  branchId: string;
  status: VisitStatus;
  priority: VisitPriority;
  queueNo: number | null;
  scheduledAt: string | null;
  checkedInAt: string | null;
  startedAt: string | null;
  signedAt: string | null;
  createdAt: string;
  petId: string;
  petName: string;
  speciesName: string | null;
  customerId: string;
  customerName: string;
  customerPhone: string;
  reason: string | null;
  vetId: string | null;
  vetName: string | null;
  weightKg: number | null;
  outcome: VisitOutcome | null;
  recheckOn: string | null;
  followUpOf: string | null;
  diagnosesText: string | null;
  /** Only in the queue. */
  hasAllergy: boolean;
  hasBehavior: boolean;
  contagious: boolean;
  /** Only in the pet history. */
  branchName: string | null;
  ownerInstructions: string | null;
};

export type MedicalQueue = {
  date: string;
  counts: { scheduled: number; waiting: number; inProgress: number; done: number };
  rows: MedicalVisit[];
};

export type VisitFilter = { from?: string; to?: string; status?: VisitStatus | ""; vetId?: string; search?: string };

export type VisitDiagnosis = { id: string; termId: string | null; name: string; isContagious: boolean; note: string | null };
export type VisitAddendum = { id: string; content: string; createdByName: string | null; createdAt: string };

export type VisitPet = {
  id: string;
  name: string;
  speciesName: string;
  breed: string | null;
  sex: string | null;
  neutered: boolean | null;
  birthDate: string | null;
  allergies: string | null;
  behaviorNotes: string | null;
  status: string;
  photoUrl: string | null;
  lastWeightKg: number | null;
};

/** One visit with its record. */
export type MedicalVisitDetail = MedicalVisit & {
  branchName: string;
  source: VisitSource;
  subjective: string | null;
  objective: string | null;
  assessment: string | null;
  plan: string | null;
  temperatureC: number | null;
  heartRate: number | null;
  respRate: number | null;
  vitalsNote: string | null;
  signedByName: string | null;
  cancelledAt: string | null;
  cancelReason: string | null;
  followUpCode: string | null;
  recheckVisit: { id: string; code: string; scheduledAt: string | null; status: VisitStatus } | null;
  pet: VisitPet | null;
  diagnoses: VisitDiagnosis[];
  addenda: VisitAddendum[];
};

export type Vet = { id: string; name: string };

export type CheckInInput = {
  branchId: string;
  customerId: string;
  petId: string;
  reason: string;
  priority: VisitPriority;
  vetId: string | null;
  weightKg: number | null;
  temperatureC: number | null;
  /** The booked visit being checked in; the other fields are then taken from it. */
  visitId?: string;
  source?: VisitSource;
};

export type ScheduleInput = {
  branchId: string;
  customerId: string;
  petId: string;
  /** ISO timestamp. */
  scheduledAt: string;
  reason: string;
  vetId: string | null;
};

/** What the vet writes on the record; also what Save sends. */
export type RecordInput = {
  weightKg: number | null;
  temperatureC: number | null;
  heartRate: number | null;
  respRate: number | null;
  vitalsNote: string;
  subjective: string;
  objective: string;
  assessment: string;
  plan: string;
  ownerInstructions: string;
  outcome: VisitOutcome | null;
  recheckOn: string;
  diagnoses: { termId: string | null; name: string; isContagious: boolean; note: string }[];
};

export type SignResult = { id: string; status: VisitStatus; recheckVisitId: string | null };
