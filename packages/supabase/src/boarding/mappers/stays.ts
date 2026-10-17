// Stay rows (`boarding_stay_json` and friends) -> domain types. Pure: no client, no Vue.
import type {
  BillableBoardingStay,
  BoardingStay,
  CareLog,
  CheckoutPreview,
  CheckoutPreviewRow,
  BillableStayRow,
  CareLogRow,
  QuoteRow,
  StayChargeRow,
  StayCharge,
  StayPet,
  StayQuote,
  StayRow,
  TypeAvailability,
  TypeAvailabilityRow,
} from "@bongcun/core/boarding";

type PetRow = NonNullable<StayRow["pets"]>[number];

export const toStayPet = (row: PetRow): StayPet => ({
  id: row.id,
  lineNo: row.line_no,
  petId: row.pet_id,
  petName: row.pet_name,
  petPhotoUrl: row.pet_photo_url ?? null,
  status: row.status,
  kennelTypeId: row.kennel_type_id,
  kennelTypeName: row.kennel_type_name,
  kennelId: row.kennel_id,
  kennelCode: row.kennel_code,
  nightsFrom: row.nights_from,
  nightsTo: row.nights_to,
  chargedNights: row.charged_nights,
  isExtraPet: row.is_extra_pet,
  estNightPrice: row.est_night_price,
  nightPrice: row.night_price ?? null,
  weightKg: row.weight_kg ?? null,
  vaccineChecked: row.vaccine_checked,
  vaccineNote: row.vaccine_note ?? null,
  belongings: row.belongings ?? null,
  belongingsReturned: row.belongings_returned,
  feeding: row.feeding ?? null,
  medication: row.medication ?? null,
  hasNotes: row.has_notes,
});

export const toCareLog = (row: CareLogRow): CareLog => ({
  id: row.id,
  stayPetId: row.stay_pet_id,
  petName: row.pet_name,
  kind: row.kind,
  mealEaten: row.meal_eaten ?? null,
  content: row.content ?? null,
  visibleToCustomer: row.visible_to_customer,
  loggedAt: row.logged_at,
  createdByName: row.created_by_name ?? null,
  canDelete: row.can_delete,
});

export const toCharge = (row: StayChargeRow): StayCharge => ({
  id: row.id,
  stayPetId: row.stay_pet_id ?? null,
  petName: row.pet_name ?? null,
  kind: row.kind,
  name: row.name,
  qty: row.qty,
  unitPrice: row.unit_price,
  amount: row.amount,
  invoiceLineId: row.invoice_line_id ?? null,
});

export const toBoardingStay = (row: StayRow): BoardingStay => ({
  id: row.id,
  code: row.code,
  branchId: row.branch_id,
  status: row.status,
  customerId: row.customer_id,
  customerName: row.customer_name,
  customerPhone: row.customer_phone,
  plannedInAt: row.planned_in_at,
  plannedOutAt: row.planned_out_at,
  checkedInAt: row.checked_in_at ?? null,
  checkedOutAt: row.checked_out_at ?? null,
  source: row.source,
  kind: row.kind,
  visitId: row.visit_id ?? null,
  visitCode: row.visit_code ?? null,
  emergencyPhone: row.emergency_phone ?? null,
  note: row.note ?? null,
  cancelReason: row.cancel_reason ?? null,
  estTotal: row.est_total,
  pets: (row.pets ?? []).map(toStayPet),
  careLogs: (row.care_logs ?? []).map(toCareLog),
  charges: (row.charges ?? []).map(toCharge),
});

export const toQuote = (row: QuoteRow): StayQuote => ({
  nights: row.nights,
  total: row.total,
  items: (row.items ?? []).map((item) => ({
    lineNo: item.line_no,
    petId: item.pet_id,
    petName: item.pet_name,
    kennelTypeId: item.kennel_type_id,
    kennelTypeName: item.kennel_type_name,
    kennelId: item.kennel_id,
    kennelCode: item.kennel_code,
    isExtraPet: item.is_extra_pet,
    nightPrice: item.night_price,
    amount: item.amount,
    warnings: item.warnings ?? [],
  })),
});

export const toTypeAvailability = (row: TypeAvailabilityRow): TypeAvailability => ({
  kennelTypeId: row.kennel_type_id,
  name: row.name,
  total: row.total,
  free: row.free,
  nightPrice: row.night_price ?? null,
});

export const toCheckoutPreview = (row: CheckoutPreviewRow): CheckoutPreview => ({
  at: row.at,
  items: (row.items ?? []).map((item) => ({
    stayPetId: item.stay_pet_id ?? null,
    petName: item.pet_name ?? null,
    kind: item.kind,
    name: item.name,
    qty: item.qty,
    unitPrice: item.unit_price,
    amount: item.amount,
  })),
  total: row.total,
  belongings: (row.belongings ?? []).map((item) => ({
    stayPetId: item.stay_pet_id,
    petName: item.pet_name,
    belongings: item.belongings,
    returned: item.returned,
  })),
});

export const toBillableStay = (row: BillableStayRow): BillableBoardingStay => ({
  stayId: row.stay_id,
  code: row.code,
  total: row.total,
  charges: row.charges.map((charge) => ({
    id: charge.id,
    name: charge.name,
    petName: charge.pet_name ?? null,
    petPhotoUrl: charge.pet_photo_url ?? null,
    qty: charge.qty,
    unitPrice: charge.unit_price,
    amount: charge.amount,
  })),
});
