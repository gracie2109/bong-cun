// Contract of the medical visit functions (queue, list, record, lines, prescription, billing).
// Inputs are camel-case; result schemas describe the `jsonb` the database answers with.
import { z } from "zod";

const uuid = z.string().uuid();

export const visitStatusSchema = z.enum(["scheduled", "waiting", "in_progress", "done", "paid", "cancelled", "no_show"]);
export const visitPrioritySchema = z.enum(["normal", "urgent"]);
export const visitOutcomeSchema = z.enum(["home", "recheck", "inpatient", "referred", "deceased"]);
export const visitSourceSchema = z.enum(["counter", "phone", "recheck", "web"]);
export const itemKindSchema = z.enum(["service", "product", "external"]);

// ---------------------------------------------------------------- inputs
/** `check_in_medical_visit`: walks a pet in, or checks in a booked visit (then `visitId` is set). */
export const checkInInput = z.object({
  branchId: uuid,
  customerId: uuid,
  petId: uuid,
  reason: z.string(),
  priority: visitPrioritySchema,
  vetId: uuid.nullable(),
  weightKg: z.number().positive().nullable(),
  temperatureC: z.number().nullable(),
  visitId: uuid.optional(),
  source: visitSourceSchema.optional(),
});
export type CheckInInput = z.infer<typeof checkInInput>;

/** `schedule_medical_visit`. */
export const scheduleInput = z.object({
  branchId: uuid,
  customerId: uuid,
  petId: uuid,
  /** ISO timestamp. */
  scheduledAt: z.string(),
  reason: z.string(),
  vetId: uuid.nullable(),
});
export type ScheduleInput = z.infer<typeof scheduleInput>;

/** `save_medical_record`: what the vet writes. */
export const recordInput = z.object({
  weightKg: z.number().positive().nullable(),
  temperatureC: z.number().nullable(),
  heartRate: z.number().nullable(),
  respRate: z.number().nullable(),
  vitalsNote: z.string(),
  subjective: z.string(),
  objective: z.string(),
  assessment: z.string(),
  plan: z.string(),
  ownerInstructions: z.string(),
  outcome: visitOutcomeSchema.nullable(),
  recheckOn: z.string(),
  diagnoses: z.array(z.object({ termId: uuid.nullable(), name: z.string(), isContagious: z.boolean(), note: z.string() })),
});
export type RecordInput = z.infer<typeof recordInput>;

export const assignVetInput = z.object({ id: uuid, vetId: uuid.nullable() });
export const addendumInput = z.object({ id: uuid, content: z.string().min(1) });
export const cancelVisitInput = z.object({ id: uuid, reason: z.string() });

/** The medicine text of a line; also what a change sends. */
export const itemDirectionsInput = z.object({
  takeHome: z.boolean(),
  dose: z.string(),
  frequency: z.string(),
  days: z.number().int().nullable(),
  route: z.string(),
  instructions: z.string(),
});
export type ItemDirections = z.infer<typeof itemDirectionsInput>;

/** `add_medical_item`. */
export const itemInput = itemDirectionsInput.extend({
  kind: itemKindSchema,
  serviceId: uuid.optional(),
  productId: uuid.optional(),
  /** Name of a medicine bought elsewhere. */
  name: z.string().optional(),
  qty: z.number().positive(),
});
export type ItemInput = z.infer<typeof itemInput>;

// ---------------------------------------------------------------- results
/** `check_in_medical_visit` answers `{ id, code, queue_no }`. */
export const checkedInVisitSchema = z.object({ id: z.string(), code: z.string(), queue_no: z.number().nullish() });

/** `sign_medical_visit`. */
export const signResultSchema = z.object({ id: z.string(), status: visitStatusSchema, recheck_visit_id: z.string().nullish() });

/** `add_medical_item` and `update_medical_item`. */
export const itemResultSchema = z.object({ id: z.string(), warnings: z.array(z.string()).nullish() });

/** A visit as `medical_visit_json` builds it. */
export const visitRowSchema = z.object({
  id: z.string(),
  code: z.string(),
  branch_id: z.string(),
  status: visitStatusSchema,
  priority: visitPrioritySchema,
  queue_no: z.number().nullish(),
  scheduled_at: z.string().nullish(),
  checked_in_at: z.string().nullish(),
  started_at: z.string().nullish(),
  signed_at: z.string().nullish(),
  created_at: z.string(),
  pet_id: z.string(),
  pet_name: z.string(),
  pet_photo_url: z.string().nullish(),
  species_name: z.string().nullish(),
  customer_id: z.string(),
  customer_name: z.string(),
  customer_phone: z.string(),
  reason: z.string().nullish(),
  vet_id: z.string().nullish(),
  vet_name: z.string().nullish(),
  weight_kg: z.number().nullish(),
  outcome: visitOutcomeSchema.nullish(),
  recheck_on: z.string().nullish(),
  follow_up_of: z.string().nullish(),
  diagnoses_text: z.string().nullish(),
  est_total: z.number().nullish(),
  /** Only in the queue. */
  has_allergy: z.boolean().nullish(),
  has_behavior: z.boolean().nullish(),
  contagious: z.boolean().nullish(),
  /** Only in the pet history and the detail. */
  branch_name: z.string().nullish(),
  owner_instructions: z.string().nullish(),
});
export type VisitRow = z.infer<typeof visitRowSchema>;

export const visitPageSchema = z.object({ rows: z.array(visitRowSchema).nullish(), total: z.number() });

export const queueSchema = z.object({
  date: z.string(),
  counts: z.object({ scheduled: z.number(), waiting: z.number(), in_progress: z.number(), done: z.number() }),
  rows: z.array(visitRowSchema).nullish(),
});

export const visitItemRowSchema = z.object({
  id: z.string(),
  kind: itemKindSchema,
  service_id: z.string().nullish(),
  product_id: z.string().nullish(),
  name: z.string(),
  qty: z.number(),
  unit_name: z.string().nullish(),
  unit_price: z.number(),
  amount: z.number(),
  take_home: z.boolean(),
  dose: z.string().nullish(),
  frequency: z.string().nullish(),
  days: z.number().nullish(),
  route: z.string().nullish(),
  instructions: z.string().nullish(),
  auto_added: z.boolean(),
  invoice_line_id: z.string().nullish(),
  created_by_name: z.string().nullish(),
  created_at: z.string(),
});

/** `get_medical_visit`: the visit with its record. */
export const visitDetailSchema = visitRowSchema.extend({
  branch_name: z.string().nullish(),
  source: visitSourceSchema,
  subjective: z.string().nullish(),
  objective: z.string().nullish(),
  assessment: z.string().nullish(),
  plan: z.string().nullish(),
  temperature_c: z.number().nullish(),
  heart_rate: z.number().nullish(),
  resp_rate: z.number().nullish(),
  vitals_note: z.string().nullish(),
  signed_by_name: z.string().nullish(),
  cancelled_at: z.string().nullish(),
  cancel_reason: z.string().nullish(),
  follow_up_code: z.string().nullish(),
  recheck_visit: z
    .object({ id: z.string(), code: z.string(), scheduled_at: z.string().nullish(), status: visitStatusSchema })
    .nullish(),
  pet: z
    .object({
      id: z.string(),
      name: z.string(),
      species_name: z.string().nullish(),
      breed: z.string().nullish(),
      sex: z.string().nullish(),
      neutered: z.boolean().nullish(),
      birth_date: z.string().nullish(),
      allergies: z.string().nullish(),
      behavior_notes: z.string().nullish(),
      status: z.string(),
      photo_url: z.string().nullish(),
      last_weight_kg: z.number().nullish(),
    })
    .nullish(),
  diagnoses: z
    .array(
      z.object({
        id: z.string(),
        term_id: z.string().nullish(),
        name: z.string(),
        is_contagious: z.boolean(),
        note: z.string().nullish(),
      })
    )
    .nullish(),
  addenda: z
    .array(z.object({ id: z.string(), content: z.string(), created_by_name: z.string().nullish(), created_at: z.string() }))
    .nullish(),
  items: z.array(visitItemRowSchema).nullish(),
});
export type VisitDetailRow = z.infer<typeof visitDetailSchema>;

/** `medical_vets`. */
export const vetsSchema = z.array(z.object({ id: z.string(), name: z.string() })).nullish();

/** `medical_prescription`. */
export const prescriptionSchema = z.object({
  code: z.string(),
  date: z.string(),
  branch_name: z.string().nullish(),
  pet_name: z.string(),
  species_name: z.string().nullish(),
  weight_kg: z.number().nullish(),
  customer_name: z.string(),
  customer_phone: z.string(),
  vet_name: z.string().nullish(),
  signed: z.boolean(),
  owner_instructions: z.string().nullish(),
  recheck_on: z.string().nullish(),
  diagnoses: z.array(z.string()).nullish(),
  items: z
    .array(
      z.object({
        name: z.string(),
        qty: z.number(),
        unit_name: z.string().nullish(),
        dose: z.string().nullish(),
        frequency: z.string().nullish(),
        days: z.number().nullish(),
        route: z.string().nullish(),
        instructions: z.string().nullish(),
        external: z.boolean(),
      })
    )
    .nullish(),
});
export type PrescriptionRow = z.infer<typeof prescriptionSchema>;

/** `billable_medical_items`: signed visits with lines that wait for payment in the POS. */
export const billableVisitSchema = z.object({
  visit_id: z.string(),
  code: z.string(),
  pet_name: z.string(),
  pet_photo_url: z.string().nullish(),
  total: z.number(),
  items: z.array(
    z.object({
      id: z.string(),
      kind: z.enum(["service", "product"]),
      name: z.string(),
      qty: z.number(),
      unit_name: z.string().nullish(),
      unit_price: z.number(),
      amount: z.number(),
    })
  ),
});
export const billableVisitsSchema = z.array(billableVisitSchema).nullish();
export type BillableVisitRow = z.infer<typeof billableVisitSchema>;
