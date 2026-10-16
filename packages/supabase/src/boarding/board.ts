// The day board of kennels.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { BoardCounts, BoardKennel, BoardPet, DayBoard, KennelPurpose, KennelState, KennelStatus, StayStatus } from "@bongcun/core/boarding";
import { unwrap } from "@bongcun/supabase/shared";
import { asRecord, str, strOrNull } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

const toBoardPet = (value: unknown): BoardPet => {
  const row = asRecord(value);
  return {
    stayId: str(row.stay_id),
    stayCode: str(row.stay_code),
    stayStatus: str(row.stay_status) as StayStatus,
    stayPetId: str(row.stay_pet_id),
    petId: str(row.pet_id),
    petName: str(row.pet_name),
    petPhotoUrl: strOrNull(row.pet_photo_url),
    customerName: str(row.customer_name),
    plannedInAt: str(row.planned_in_at),
    plannedOutAt: str(row.planned_out_at),
    hasNotes: row.has_notes === true,
    overdue: row.overdue === true,
    kind: row.kind === "inpatient" ? "inpatient" : "boarding",
    visitId: strOrNull(row.visit_id),
    visitCode: strOrNull(row.visit_code),
  };
};

const toBoardKennel = (value: unknown): BoardKennel => {
  const row = asRecord(value);
  return {
    id: str(row.id),
    code: str(row.code),
    name: strOrNull(row.name),
    kennelTypeId: str(row.kennel_type_id),
    kennelTypeName: str(row.kennel_type_name),
    purpose: str(row.purpose) as KennelPurpose,
    status: str(row.status) as KennelStatus,
    state: str(row.state) as KennelState,
    conflict: row.conflict === true,
    pets: Array.isArray(row.pets) ? row.pets.map(toBoardPet) : [],
    arriving: Array.isArray(row.arriving) ? row.arriving.map(toBoardPet) : [],
  };
};

const toCounts = (value: unknown): BoardCounts => {
  const row = asRecord(value);
  return {
    arriving: Number(row.arriving ?? 0),
    departing: Number(row.departing ?? 0),
    occupied: Number(row.occupied ?? 0),
    overdue: Number(row.overdue ?? 0),
    free: Number(row.free ?? 0),
    inpatient: Number(row.inpatient ?? 0),
  };
};

/** Every kennel of the branch with what is in it on `date` (yyyy-MM-dd). */
export const getBoardingBoard = async (client: Client, branchId: string, date: string): Promise<DayBoard> => {
  const result = asRecord(unwrap(await client.rpc("boarding_board", { p_branch: branchId, p_date: date })));
  return {
    date: str(result.date),
    counts: toCounts(result.counts),
    kennels: Array.isArray(result.kennels) ? result.kennels.map(toBoardKennel) : [],
  };
};
