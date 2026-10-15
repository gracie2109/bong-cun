// Stays: booking, listing, quoting and cancelling.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import type {
  BoardingStay,
  QuoteItem,
  QuoteWarning,
  StayFilter,
  StayInput,
  StayPet,
  StayQuote,
  StaySource,
  StayStatus,
  TypeAvailability,
} from "@/types/boarding";
import { unwrap, type Page, type PageParams } from "../shared";
import { asRecord, numOrNull, str, strOrNull } from "../spa/parse";

type Client = SupabaseClient<Database>;

const toStayPet = (value: unknown): StayPet => {
  const row = asRecord(value);
  return {
    id: str(row.id),
    lineNo: Number(row.line_no ?? 0),
    petId: str(row.pet_id),
    petName: str(row.pet_name),
    status: row.status === "cancelled" ? "cancelled" : "active",
    kennelTypeId: str(row.kennel_type_id),
    kennelTypeName: str(row.kennel_type_name),
    kennelId: str(row.kennel_id),
    kennelCode: str(row.kennel_code),
    nightsFrom: str(row.nights_from),
    nightsTo: str(row.nights_to),
    chargedNights: Number(row.charged_nights ?? 0),
    isExtraPet: row.is_extra_pet === true,
    estNightPrice: Number(row.est_night_price ?? 0),
    nightPrice: numOrNull(row.night_price),
    weightKg: numOrNull(row.weight_kg),
    vaccineChecked: row.vaccine_checked === true,
    vaccineNote: strOrNull(row.vaccine_note),
    belongings: strOrNull(row.belongings),
    belongingsReturned: row.belongings_returned === true,
    feeding: strOrNull(row.feeding),
    medication: strOrNull(row.medication),
    hasNotes: row.has_notes === true,
  };
};

export const toBoardingStay = (value: unknown): BoardingStay => {
  const row = asRecord(value);
  return {
    id: str(row.id),
    code: str(row.code),
    branchId: str(row.branch_id),
    status: str(row.status) as StayStatus,
    customerId: str(row.customer_id),
    customerName: str(row.customer_name),
    customerPhone: str(row.customer_phone),
    plannedInAt: str(row.planned_in_at),
    plannedOutAt: str(row.planned_out_at),
    checkedInAt: strOrNull(row.checked_in_at),
    checkedOutAt: strOrNull(row.checked_out_at),
    source: str(row.source) as StaySource,
    emergencyPhone: strOrNull(row.emergency_phone),
    note: strOrNull(row.note),
    cancelReason: strOrNull(row.cancel_reason),
    estTotal: Number(row.est_total ?? 0),
    pets: Array.isArray(row.pets) ? row.pets.map(toStayPet) : [],
  };
};

export const listBoardingStays = async (
  client: Client,
  branchId: string,
  page: PageParams,
  filter: StayFilter = {}
): Promise<Page<BoardingStay>> => {
  const result = asRecord(
    unwrap(
      await client.rpc("list_boarding_stays", {
        p_branch: branchId,
        p_from: filter.from || undefined,
        p_to: filter.to || undefined,
        p_status: filter.status || undefined,
        p_search: filter.search?.trim() || undefined,
        p_page: page.pageIndex,
        p_page_size: page.pageSize,
      })
    )
  );
  const rows = Array.isArray(result.rows) ? result.rows : [];
  return { rows: rows.map(toBoardingStay), total: Number(result.total ?? 0) };
};

export const getBoardingStay = async (client: Client, id: string): Promise<BoardingStay> =>
  toBoardingStay(unwrap(await client.rpc("get_boarding_stay", { p_id: id })));

const toPayload = (branchId: string | null, input: StayInput) => ({
  ...(branchId ? { branch_id: branchId } : {}),
  customer_id: input.customerId,
  planned_in_at: input.plannedInAt,
  planned_out_at: input.plannedOutAt,
  source: input.source,
  emergency_phone: input.emergencyPhone.trim(),
  note: input.note.trim(),
  pets: input.pets.map((pet) => ({
    pet_id: pet.petId,
    kennel_type_id: pet.kennelTypeId,
    kennel_id: pet.kennelId || null,
    share_with: pet.shareWith ?? null,
    feeding: pet.feeding?.trim() ?? "",
    medication: pet.medication?.trim() ?? "",
    belongings: pet.belongings?.trim() ?? "",
  })),
});

/** Books a new stay (no id) or replaces a booked one. Returns the stay's id and code. */
export const saveBoardingStay = async (
  client: Client,
  branchId: string,
  input: StayInput,
  id?: string
): Promise<{ id: string; code: string }> => {
  const result = asRecord(
    unwrap(await client.rpc("save_boarding_stay", { p: toPayload(branchId, input), p_id: id }))
  );
  return { id: str(result.id), code: str(result.code) };
};

const toQuoteItem = (value: unknown): QuoteItem => {
  const row = asRecord(value);
  return {
    lineNo: Number(row.line_no ?? 0),
    petId: str(row.pet_id),
    petName: str(row.pet_name),
    kennelTypeId: str(row.kennel_type_id),
    kennelTypeName: str(row.kennel_type_name),
    kennelId: str(row.kennel_id),
    kennelCode: str(row.kennel_code),
    isExtraPet: row.is_extra_pet === true,
    nightPrice: Number(row.night_price ?? 0),
    amount: Number(row.amount ?? 0),
    warnings: Array.isArray(row.warnings) ? (row.warnings as QuoteWarning[]) : [],
  };
};

/** The price and the kennels a booking would get, nothing saved. `stayId` = the stay being edited. */
export const quoteBoardingStay = async (
  client: Client,
  branchId: string,
  input: StayInput,
  stayId?: string
): Promise<StayQuote> => {
  const result = asRecord(
    unwrap(await client.rpc("boarding_quote", { p_branch: branchId, p: toPayload(null, input), p_stay: stayId }))
  );
  return {
    nights: Number(result.nights ?? 0),
    total: Number(result.total ?? 0),
    items: Array.isArray(result.items) ? result.items.map(toQuoteItem) : [],
  };
};

export const getTypeAvailability = async (
  client: Client,
  branchId: string,
  from: string,
  to: string
): Promise<TypeAvailability[]> => {
  const rows = unwrap(await client.rpc("boarding_availability", { p_branch: branchId, p_from: from, p_to: to }));
  return (Array.isArray(rows) ? rows : []).map((value) => {
    const row = asRecord(value);
    return {
      kennelTypeId: str(row.kennel_type_id),
      name: str(row.name),
      total: Number(row.total ?? 0),
      free: Number(row.free ?? 0),
      nightPrice: numOrNull(row.night_price),
    };
  });
};

export const cancelBoardingStay = async (client: Client, id: string, reason?: string): Promise<void> => {
  unwrap(await client.rpc("cancel_boarding_stay", { p_id: id, p_reason: reason?.trim() || undefined }));
};

export const markBoardingNoShow = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("mark_boarding_no_show", { p_id: id }));
};
