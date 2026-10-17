// Board, calendar, kennel, settings and public catalog rows -> domain types. Pure: no client, no Vue.
import type {
  BoardCounts,
  BoardingRules,
  BoardingRulesRow,
  BoardingTimeline,
  BoardingWebCatalog,
  BoardKennel,
  BoardPet,
  BoardRow,
  DayBoard,
  Kennel,
  KennelRow,
  KennelType,
  KennelTypeRow,
  PublicCatalogRow,
  TimelineRow,
} from "@bongcun/core/boarding";

type BoardPetRow = NonNullable<NonNullable<BoardRow["kennels"]>[number]["pets"]>[number];
type BoardKennelRow = NonNullable<BoardRow["kennels"]>[number];
type TimelineKennelRow = NonNullable<TimelineRow["kennels"]>[number];

const toBoardPet = (row: BoardPetRow): BoardPet => ({
  stayId: row.stay_id,
  stayCode: row.stay_code,
  stayStatus: row.stay_status,
  stayPetId: row.stay_pet_id,
  petId: row.pet_id,
  petName: row.pet_name,
  petPhotoUrl: row.pet_photo_url ?? null,
  customerName: row.customer_name,
  plannedInAt: row.planned_in_at,
  plannedOutAt: row.planned_out_at,
  hasNotes: row.has_notes,
  overdue: row.overdue,
  kind: row.kind,
  visitId: row.visit_id ?? null,
  visitCode: row.visit_code ?? null,
});

const toBoardKennel = (row: BoardKennelRow): BoardKennel => ({
  id: row.id,
  code: row.code,
  name: row.name ?? null,
  kennelTypeId: row.kennel_type_id,
  kennelTypeName: row.kennel_type_name,
  purpose: row.purpose,
  status: row.status,
  state: row.state,
  conflict: row.conflict,
  pets: (row.pets ?? []).map(toBoardPet),
  arriving: (row.arriving ?? []).map(toBoardPet),
});

export const toDayBoard = (row: BoardRow): DayBoard => {
  const counts: BoardCounts = row.counts;
  return { date: row.date, counts, kennels: (row.kennels ?? []).map(toBoardKennel) };
};

const toTimelineKennel = (row: TimelineKennelRow) => ({
  id: row.id,
  code: row.code,
  name: row.name ?? null,
  kennelTypeId: row.kennel_type_id,
  kennelTypeName: row.kennel_type_name,
  status: row.status,
  segments: (row.segments ?? []).map((segment) => ({
    stayId: segment.stay_id,
    stayCode: segment.stay_code,
    stayStatus: segment.stay_status,
    stayPetId: segment.stay_pet_id,
    petName: segment.pet_name,
    customerName: segment.customer_name,
    kind: segment.kind,
    visitCode: segment.visit_code ?? null,
    from: segment.from,
    to: segment.to,
  })),
});

export const toTimeline = (row: TimelineRow): BoardingTimeline => ({
  from: row.from,
  days: row.days,
  kennels: (row.kennels ?? []).map(toTimelineKennel),
});

export const toKennel = (row: KennelRow): Kennel => ({
  id: row.id,
  branchId: row.branch_id,
  kennelTypeId: row.kennel_type_id,
  kennelTypeName: row.kennel_type_name,
  code: row.code,
  name: row.name ?? null,
  status: row.status,
  isActive: row.is_active,
  sortOrder: row.sort_order,
});

export const toKennelType = (row: KennelTypeRow): KennelType => ({
  id: row.id,
  name: row.name,
  description: row.description ?? null,
  photoUrl: row.photo_url ?? null,
  speciesIds: row.species_ids ?? [],
  speciesNames: row.species_names ?? [],
  maxWeightKg: row.max_weight_kg ?? null,
  maxPets: row.max_pets,
  purpose: row.purpose,
  isActive: row.is_active,
  isPublic: row.is_public,
  sortOrder: row.sort_order,
  nightPrice: row.night_price ?? null,
  extraPetNightPrice: row.extra_pet_night_price ?? null,
  hasBranchPrice: row.has_branch_price,
  sharedNightPrice: row.shared_night_price ?? null,
  sharedExtraPetNightPrice: row.shared_extra_pet_night_price ?? null,
  branchPrices: (row.branch_prices ?? []).map((price) => ({
    branchId: price.branch_id,
    branchName: price.branch_name,
    nightPrice: price.night_price,
    extraPetNightPrice: price.extra_pet_night_price ?? null,
  })),
  kennelCount: row.kennel_count,
});

export const toBoardingRules = (row: BoardingRulesRow): BoardingRules => ({
  checkInFrom: row.check_in_from,
  checkOutBy: row.check_out_by,
  lateHalfUntil: row.late_half_until,
  maxNights: row.max_nights,
  dayStayNights: row.day_stay_nights,
});

export const toPublicCatalog = (row: PublicCatalogRow): BoardingWebCatalog => ({
  branch: row.branch ? { id: row.branch.id, name: row.branch.name, phone: row.branch.phone ?? "" } : null,
  rules: row.rules
    ? { checkInFrom: row.rules.check_in_from, checkOutBy: row.rules.check_out_by, lateHalfUntil: row.rules.late_half_until }
    : null,
  kennelTypes: (row.kennel_types ?? []).map((type) => ({
    id: type.id,
    name: type.name,
    description: type.description ?? "",
    photoUrl: type.photo_url ?? null,
    maxWeightKg: type.max_weight_kg ?? null,
    maxPets: type.max_pets,
    nightPrice: type.night_price,
    extraPetNightPrice: type.extra_pet_night_price ?? null,
    species: type.species ?? [],
  })),
});
