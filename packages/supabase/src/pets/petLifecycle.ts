// Marking a pet deceased and bringing it back (see 20261025010000_pet_deceased.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "@bongcun/supabase/db";
import { unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

/** A booking, hotel stay or visit that is still ahead. `whole` is false when another pet keeps it alive. */
export type DeceasedBooking = {
  id: string;
  code: string;
  startAt: string;
  branchName: string;
  whole: boolean;
};

/** Work in progress that stays as it is and is finished by hand. */
export type DeceasedOpenItem = { type: "appointment" | "visit"; id: string; code: string; status: string };

/** A kennel the pet is in now; it must leave before it can be marked deceased. */
export type DeceasedBlocker = { type: "boarding" | "inpatient"; id: string; code: string };

export type DeceasedPreview = {
  appointments: DeceasedBooking[];
  stays: DeceasedBooking[];
  visits: DeceasedBooking[];
  blocking: DeceasedBlocker[];
  open: DeceasedOpenItem[];
};

export type MarkDeceasedInput = { deceasedOn?: string | null; note?: string | null };

export type MarkDeceasedResult = { appointments: number; stays: number; visits: number };

type Row = Record<string, unknown>;
const rows = (value: unknown): Row[] => (Array.isArray(value) ? (value as Row[]) : []);
const text = (value: unknown): string => (typeof value === "string" ? value : "");

const toBooking = (row: Row): DeceasedBooking => ({
  id: text(row.id),
  code: text(row.code),
  startAt: text(row.start_at),
  branchName: text(row.branch_name),
  whole: row.whole !== false,
});

export const toDeceasedPreview = (json: Json): DeceasedPreview => {
  const root = (json ?? {}) as Row;
  return {
    appointments: rows(root.appointments).map(toBooking),
    stays: rows(root.stays).map(toBooking),
    visits: rows(root.visits).map(toBooking),
    blocking: rows(root.blocking).map((row) => ({
      type: row.type === "inpatient" ? "inpatient" : "boarding",
      id: text(row.id),
      code: text(row.code),
    })),
    open: rows(root.open).map((row) => ({
      type: row.type === "visit" ? "visit" : "appointment",
      id: text(row.id),
      code: text(row.code),
      status: text(row.status),
    })),
  };
};

/** What marking the pet deceased would cancel, and what is left to finish by hand. */
export const petDeceasedPreview = async (client: Client, petId: string): Promise<DeceasedPreview> =>
  toDeceasedPreview(unwrap(await client.rpc("pet_deceased_preview", { p_pet: petId })));

export const markPetDeceased = async (
  client: Client,
  petId: string,
  input: MarkDeceasedInput = {}
): Promise<MarkDeceasedResult> => {
  const json = unwrap(
    await client.rpc("mark_pet_deceased", {
      p_pet: petId,
      p: { deceased_on: input.deceasedOn || null, note: input.note?.trim() || null },
    })
  ) as { cancelled?: Record<string, number> } | null;
  const cancelled = json?.cancelled ?? {};
  return {
    appointments: Number(cancelled.appointments ?? 0),
    stays: Number(cancelled.stays ?? 0),
    visits: Number(cancelled.visits ?? 0),
  };
};

/** Back to active: the date and note of death are cleared; cancelled bookings stay cancelled. */
export const restorePet = async (client: Client, petId: string): Promise<void> => {
  unwrap(await client.rpc("restore_pet", { p_pet: petId }));
};
