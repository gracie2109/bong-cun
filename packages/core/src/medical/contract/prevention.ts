// Contract of the vaccination, catalog, settings, health-flag and attachment functions. Inputs are
// camel-case; result schemas describe the `jsonb` the database answers with.
import { z } from "zod";

const uuid = z.string().uuid();

export const vaccineKindSchema = z.enum(["vaccine", "deworm", "other"]);
export const bookStateSchema = z.enum(["ok", "due_soon", "overdue"]);
export const reminderKindSchema = z.enum(["vaccination", "recheck"]);
export const attachmentKindSchema = z.enum(["lab", "imaging", "photo", "consent", "other"]);

// ---------------------------------------------------------------- inputs
/** `give_vaccination`: a shot given in a visit. */
export const giveVaccineInput = z.object({
  vaccineTypeId: uuid,
  lotId: uuid.nullable(),
  doseNo: z.number().int().positive().nullable(),
  nextDueOn: z.string().nullable(),
});
export type GiveVaccineInput = z.infer<typeof giveVaccineInput>;

/** `add_external_vaccination`: a shot typed in from another clinic. */
export const externalVaccineInput = z.object({
  vaccineTypeId: uuid,
  givenOn: z.string(),
  externalPlace: z.string(),
  lotNo: z.string(),
  expiryDate: z.string(),
  doseNo: z.number().int().positive().nullable(),
  nextDueOn: z.string().nullable(),
});
export type ExternalVaccineInput = z.infer<typeof externalVaccineInput>;

export const voidVaccinationInput = z.object({ id: uuid, reason: z.string() });
export const markRemindedInput = z.object({ vaccinationId: uuid, note: z.string() });

/** `save_diagnosis_term`. */
export const diagnosisTermInput = z.object({
  name: z.string().min(1),
  speciesIds: z.array(uuid),
  isContagious: z.boolean(),
  isActive: z.boolean(),
  sortOrder: z.number().int(),
});
export type DiagnosisTermInput = z.infer<typeof diagnosisTermInput>;

/** `save_vaccine_type`. */
export const vaccineTypeInput = z.object({
  name: z.string().min(1),
  kind: vaccineKindSchema,
  speciesIds: z.array(uuid),
  productId: uuid.nullable(),
  seriesDoses: z.number().int().positive(),
  seriesIntervalDays: z.number().int().positive().nullable(),
  boosterIntervalDays: z.number().int().positive().nullable(),
  minAgeWeeks: z.number().int().min(0).nullable(),
  isActive: z.boolean(),
  sortOrder: z.number().int(),
});
export type VaccineTypeInput = z.infer<typeof vaccineTypeInput>;

/** `save_medical_settings`: the medical rules of a branch. */
export const medicalRulesInput = z.object({
  /** Service added when a vet takes a case; null = none. */
  examServiceId: uuid.nullable(),
  examServiceName: z.string().nullable(),
  remindAheadDays: z.number().int().min(0),
  contagiousDays: z.number().int().min(0),
  requireVaccineForBoarding: z.boolean(),
});
export type MedicalRules = z.infer<typeof medicalRulesInput>;

/** `add_medical_attachment` (after the file is uploaded). */
export const attachmentInput = z.object({
  visitId: uuid,
  kind: attachmentKindSchema,
  title: z.string(),
  filePath: z.string(),
  mimeType: z.string(),
  sizeBytes: z.number().int().positive(),
});

// ---------------------------------------------------------------- results
export const vaccineDoseRowSchema = z.object({
  id: z.string(),
  dose_no: z.number(),
  given_on: z.string(),
  lot_no: z.string().nullish(),
  expiry_date: z.string().nullish(),
  is_external: z.boolean(),
  external_place: z.string().nullish(),
  vet_name: z.string().nullish(),
  next_due_on: z.string().nullish(),
  branch_name: z.string().nullish(),
  visit_id: z.string().nullish(),
  voided_at: z.string().nullish(),
});

/** `pet_vaccinations`: the e-book of one pet. */
export const vaccineBookSchema = z
  .array(
    z.object({
      vaccine_type_id: z.string(),
      name: z.string(),
      kind: z.string(),
      state: bookStateSchema,
      next_due_on: z.string().nullish(),
      last_given_on: z.string(),
      doses: z.array(vaccineDoseRowSchema).nullish(),
    })
  )
  .nullish();
export type VaccineBookRow = NonNullable<z.infer<typeof vaccineBookSchema>>[number];

/** `vaccine_lots`. */
export const vaccineLotsSchema = z
  .array(z.object({ id: z.string(), lot_no: z.string(), expiry_date: z.string().nullish(), qty_on_hand: z.number() }))
  .nullish();

/** `give_vaccination`. */
export const givenVaccineSchema = z.object({
  id: z.string(),
  item_id: z.string().nullish(),
  warnings: z.array(z.string()).nullish(),
});

export const reminderRowSchema = z.object({
  kind: reminderKindSchema,
  vaccination_id: z.string().nullish(),
  visit_id: z.string().nullish(),
  pet_id: z.string(),
  pet_name: z.string(),
  species_name: z.string().nullish(),
  customer_id: z.string(),
  customer_name: z.string(),
  customer_phone: z.string(),
  vaccine_name: z.string().nullish(),
  due_on: z.string(),
  last_given_on: z.string().nullish(),
  reminded_at: z.string().nullish(),
  remind_note: z.string().nullish(),
  reminded_by_name: z.string().nullish(),
});
export type ReminderRow = z.infer<typeof reminderRowSchema>;

/** `medical_reminders` answers one page. */
export const reminderPageSchema = z.object({ rows: z.array(reminderRowSchema).nullish(), total: z.number() });

export const vaccineTypeRowSchema = z.object({
  id: z.string(),
  name: z.string(),
  kind: vaccineKindSchema,
  species_ids: z.array(z.string()).nullish(),
  species_names: z.array(z.string()).nullish(),
  product_id: z.string().nullish(),
  product_name: z.string().nullish(),
  product_unit: z.string().nullish(),
  stock_qty: z.number().nullish(),
  series_doses: z.number(),
  series_interval_days: z.number().nullish(),
  booster_interval_days: z.number().nullish(),
  min_age_weeks: z.number().nullish(),
  is_active: z.boolean(),
  sort_order: z.number(),
});
export type VaccineTypeRow = z.infer<typeof vaccineTypeRowSchema>;
export const vaccineTypePageSchema = z.object({ rows: z.array(vaccineTypeRowSchema).nullish(), total: z.number() });

export const diagnosisTermRowSchema = z.object({
  id: z.string(),
  name: z.string(),
  species_ids: z.array(z.string()).nullish(),
  species_names: z.array(z.string()).nullish(),
  is_contagious: z.boolean(),
  is_active: z.boolean(),
  sort_order: z.number(),
});
export type DiagnosisTermRow = z.infer<typeof diagnosisTermRowSchema>;
export const diagnosisTermPageSchema = z.object({ rows: z.array(diagnosisTermRowSchema).nullish(), total: z.number() });

/** `medical_settings_get`. */
export const medicalRulesRowSchema = z.object({
  exam_service_id: z.string().nullish(),
  exam_service_name: z.string().nullish(),
  remind_ahead_days: z.number(),
  contagious_days: z.number(),
  require_vaccine_for_boarding: z.boolean(),
});
export type MedicalRulesRow = z.infer<typeof medicalRulesRowSchema>;

/** `pet_health_flags`: an object keyed by pet id. */
export const petHealthFlagsSchema = z
  .record(
    z.string(),
    z.object({ contagious: z.boolean(), vaccine_overdue: z.boolean(), allergies: z.string().nullish() })
  )
  .nullish();

export const attachmentRowSchema = z.object({
  id: z.string(),
  visit_id: z.string(),
  kind: attachmentKindSchema,
  title: z.string(),
  file_path: z.string(),
  mime_type: z.string(),
  size_bytes: z.number(),
  created_by_name: z.string().nullish(),
  created_at: z.string(),
});
export type AttachmentRow = z.infer<typeof attachmentRowSchema>;
export const attachmentsSchema = z.array(attachmentRowSchema).nullish();
