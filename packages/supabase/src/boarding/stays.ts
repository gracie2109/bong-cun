// Stays: booking, listing, quoting and cancelling.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import {
  quoteSchema,
  savedStaySchema,
  stayPageSchema,
  stayRowSchema,
  typeAvailabilitySchema,
} from "@bongcun/core/boarding";
import type { BoardingStay, StayFilter, StayInput, StayQuote, TypeAvailability } from "@bongcun/core/boarding";
import { parseRpc, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { toBoardingStay, toQuote, toTypeAvailability } from "./mappers";

type Client = SupabaseClient<Database>;

export const listBoardingStays = async (
  client: Client,
  branchId: string,
  page: PageParams,
  filter: StayFilter = {}
): Promise<Page<BoardingStay>> => {
  const raw = unwrap(
    await client.rpc("list_boarding_stays", {
      p_branch: branchId,
      p_from: filter.from || undefined,
      p_to: filter.to || undefined,
      p_status: filter.status || undefined,
      p_search: filter.search?.trim() || undefined,
      p_page: page.pageIndex,
      p_page_size: page.pageSize,
    })
  );
  const result = parseRpc("list_boarding_stays", stayPageSchema, raw);
  return { rows: (result.rows ?? []).map(toBoardingStay), total: result.total };
};

export const getBoardingStay = async (client: Client, id: string): Promise<BoardingStay> =>
  toBoardingStay(parseRpc("get_boarding_stay", stayRowSchema, unwrap(await client.rpc("get_boarding_stay", { p_id: id }))));

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
  const raw = unwrap(await client.rpc("save_boarding_stay", { p: toPayload(branchId, input), p_id: id }));
  return parseRpc("save_boarding_stay", savedStaySchema, raw);
};

/** The price and the kennels a booking would get, nothing saved. `stayId` = the stay being edited. */
export const quoteBoardingStay = async (
  client: Client,
  branchId: string,
  input: StayInput,
  stayId?: string
): Promise<StayQuote> => {
  const raw = unwrap(await client.rpc("boarding_quote", { p_branch: branchId, p: toPayload(null, input), p_stay: stayId }));
  return toQuote(parseRpc("boarding_quote", quoteSchema, raw));
};

export const getTypeAvailability = async (
  client: Client,
  branchId: string,
  from: string,
  to: string
): Promise<TypeAvailability[]> => {
  const raw = unwrap(await client.rpc("boarding_availability", { p_branch: branchId, p_from: from, p_to: to }));
  return (parseRpc("boarding_availability", typeAvailabilitySchema, raw) ?? []).map(toTypeAvailability);
};

export const cancelBoardingStay = async (client: Client, id: string, reason?: string): Promise<void> => {
  unwrap(await client.rpc("cancel_boarding_stay", { p_id: id, p_reason: reason?.trim() || undefined }));
};

export const markBoardingNoShow = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("mark_boarding_no_show", { p_id: id }));
};
