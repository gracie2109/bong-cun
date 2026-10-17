// Contract of the in-patient functions. Inputs are camel-case; result schemas describe the `jsonb`
// the database answers with (see 20261021080100_inpatient_rpcs.sql and 20261023010000).
import { z } from "zod";

const uuid = z.string().uuid();

export const orderKindSchema = z.enum(["product", "service", "care"]);
export type OrderKind = z.infer<typeof orderKindSchema>;
export const logKindSchema = z.enum(["vitals", "treatment", "note"]);
export type LogKind = z.infer<typeof logKindSchema>;
export const kennelPurposeSchema = z.enum(["medical", "isolation"]);
export const orderActionSchema = z.enum(["create", "update", "stop", "replace"]);

// ---------------------------------------------------------------- inputs
/** `admit_inpatient`. */
export const admitInput = z.object({ kennelId: uuid, plannedOutAt: z.string().nullable(), note: z.string() });
export type AdmitInput = z.infer<typeof admitInput>;

/** `save_inpatient_order` and `replace_inpatient_order`. */
export const orderInput = z.object({
  stayPetId: uuid,
  kind: orderKindSchema,
  productId: uuid.nullable(),
  serviceId: uuid.nullable(),
  name: z.string(),
  dose: z.string(),
  qtyPerDose: z.number().positive(),
  times: z.array(z.string()),
  startOn: z.string(),
  endOn: z.string(),
  note: z.string(),
});
export type OrderInput = z.infer<typeof orderInput>;

/** `add_inpatient_log`. */
export const inpatientLogInput = z.object({ kind: logKindSchema, content: z.string().min(1) });

// --------------------------------------------------------------- results
export const inpatientKennelRowSchema = z.object({
  id: z.string(),
  code: z.string(),
  type_name: z.string(),
  purpose: kennelPurposeSchema,
  free: z.boolean(),
});
export type InpatientKennelRow = z.infer<typeof inpatientKennelRowSchema>;
export const inpatientKennelsSchema = z.array(inpatientKennelRowSchema).nullish();

export const wardOrderJsonSchema = z.object({
  id: z.string(),
  kind: orderKindSchema,
  product_id: z.string().nullish(),
  service_id: z.string().nullish(),
  name: z.string(),
  dose: z.string().nullish(),
  qty_per_dose: z.number(),
  times: z.array(z.string()).nullish(),
  start_on: z.string(),
  end_on: z.string(),
  note: z.string().nullish(),
  edited: z.number().nullish(),
  missed: z.number().nullish(),
});
export type WardOrderJson = z.infer<typeof wardOrderJsonSchema>;

export const wardDoseJsonSchema = z.object({
  id: z.string(),
  order_id: z.string(),
  due_at: z.string(),
  given_at: z.string().nullish(),
  given_by_name: z.string().nullish(),
  skipped_reason: z.string().nullish(),
  qty: z.number().nullish(),
});
export type WardDoseJson = z.infer<typeof wardDoseJsonSchema>;

export const wardRowJsonSchema = z.object({
  stay_id: z.string(),
  stay_code: z.string(),
  stay_pet_id: z.string(),
  visit_id: z.string(),
  visit_code: z.string(),
  pet_id: z.string(),
  pet_name: z.string(),
  pet_photo_url: z.string().nullish(),
  customer_name: z.string(),
  customer_phone: z.string(),
  kennel_code: z.string(),
  purpose: kennelPurposeSchema,
  since: z.string(),
  planned_out_at: z.string(),
  overdue: z.boolean(),
  allergies: z.string().nullish(),
  orders: z.array(wardOrderJsonSchema).nullish(),
  doses: z.array(wardDoseJsonSchema).nullish(),
  last_vitals: z.object({ content: z.string(), logged_at: z.string() }).nullish(),
});
export type WardRowJson = z.infer<typeof wardRowJsonSchema>;

/** `inpatient_ward`. */
export const wardSchema = z.object({ date: z.string(), rows: z.array(wardRowJsonSchema).nullish() });
export type WardJson = z.infer<typeof wardSchema>;

/** `admit_inpatient`. */
export const admittedSchema = z.object({ stay_id: z.string(), stay_pet_id: z.string(), code: z.string() });

/** `give_inpatient_dose`. */
export const givenDoseSchema = z.object({ warnings: z.array(z.string()).nullish() });

/** `discharge_inpatient`. */
export const dischargedSchema = z.object({
  id: z.string(),
  code: z.string(),
  total: z.number(),
  visit_id: z.string().nullish(),
});

const orderSnapshotJsonSchema = z
  .object({
    dose: z.string().nullish(),
    qty_per_dose: z.number().nullish(),
    times: z.array(z.string()).nullish(),
    start_on: z.string().nullish(),
    end_on: z.string().nullish(),
    note: z.string().nullish(),
  })
  .passthrough();
export type OrderSnapshotJson = z.infer<typeof orderSnapshotJsonSchema>;

/** `inpatient_order_history`. */
export const orderHistorySchema = z
  .array(
    z.object({
      id: z.string(),
      action: orderActionSchema,
      before: orderSnapshotJsonSchema.nullish(),
      after: orderSnapshotJsonSchema.nullish(),
      reason: z.string().nullish(),
      changed_by_name: z.string().nullish(),
      changed_at: z.string(),
    })
  )
  .nullish();
export type OrderHistoryJson = NonNullable<z.infer<typeof orderHistorySchema>>;
