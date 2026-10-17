// In-patient rows -> domain types. Pure.
import type {
  InpatientKennel,
  InpatientKennelRow,
  OrderChange,
  OrderHistoryJson,
  OrderSnapshot,
  OrderSnapshotJson,
  Ward,
  WardDose,
  WardDoseJson,
  WardJson,
  WardOrder,
  WardOrderJson,
  WardRow,
  WardRowJson,
} from "@bongcun/core/medical";

export const toInpatientKennel = (row: InpatientKennelRow): InpatientKennel => ({
  id: row.id,
  code: row.code,
  typeName: row.type_name,
  purpose: row.purpose,
  free: row.free,
});

const toOrder = (row: WardOrderJson): WardOrder => ({
  id: row.id,
  kind: row.kind,
  productId: row.product_id ?? null,
  serviceId: row.service_id ?? null,
  name: row.name,
  dose: row.dose ?? "",
  qtyPerDose: row.qty_per_dose,
  times: row.times ?? [],
  startOn: row.start_on,
  endOn: row.end_on,
  note: row.note ?? "",
  edited: row.edited ?? 0,
  missed: row.missed ?? 0,
});

const toDose = (row: WardDoseJson): WardDose => ({
  id: row.id,
  orderId: row.order_id,
  dueAt: row.due_at,
  givenAt: row.given_at ?? null,
  givenByName: row.given_by_name ?? null,
  skippedReason: row.skipped_reason ?? null,
  qty: row.qty ?? null,
});

const toRow = (row: WardRowJson): WardRow => ({
  stayId: row.stay_id,
  stayCode: row.stay_code,
  stayPetId: row.stay_pet_id,
  visitId: row.visit_id,
  visitCode: row.visit_code,
  petId: row.pet_id,
  petName: row.pet_name,
  petPhotoUrl: row.pet_photo_url ?? null,
  customerName: row.customer_name,
  customerPhone: row.customer_phone,
  kennelCode: row.kennel_code,
  purpose: row.purpose,
  since: row.since,
  plannedOutAt: row.planned_out_at,
  overdue: row.overdue,
  allergies: row.allergies ?? null,
  orders: (row.orders ?? []).map(toOrder),
  doses: (row.doses ?? []).map(toDose),
  lastVitals: row.last_vitals ? { content: row.last_vitals.content, loggedAt: row.last_vitals.logged_at } : null,
});

export const toWard = (data: WardJson): Ward => ({ date: data.date, rows: (data.rows ?? []).map(toRow) });

const toSnapshot = (value: OrderSnapshotJson | null | undefined): Partial<OrderSnapshot> | null =>
  value
    ? {
        dose: value.dose ?? null,
        qtyPerDose: value.qty_per_dose ?? undefined,
        times: value.times ?? undefined,
        startOn: value.start_on ?? undefined,
        endOn: value.end_on ?? undefined,
        note: value.note ?? null,
      }
    : null;

export const toOrderHistory = (rows: OrderHistoryJson): OrderChange[] =>
  rows.map((row) => ({
    id: row.id,
    action: row.action,
    before: toSnapshot(row.before),
    after: toSnapshot(row.after),
    reason: row.reason ?? null,
    changedByName: row.changed_by_name ?? null,
    changedAt: row.changed_at,
  }));
