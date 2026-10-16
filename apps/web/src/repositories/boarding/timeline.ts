// The kennel calendar and moving a pet to another kennel.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import type { BoardingTimeline, KennelStatus, StayStatus, TimelineKennel, TimelineSegment } from "@/types/boarding";
import { unwrap } from "../shared";
import { asRecord, str, strOrNull } from "../spa/parse";

type Client = SupabaseClient<Database>;

const toSegment = (value: unknown): TimelineSegment => {
  const row = asRecord(value);
  return {
    stayId: str(row.stay_id),
    stayCode: str(row.stay_code),
    stayStatus: str(row.stay_status) as StayStatus,
    stayPetId: str(row.stay_pet_id),
    petName: str(row.pet_name),
    customerName: str(row.customer_name),
    from: str(row.from),
    to: str(row.to),
  };
};

const toKennel = (value: unknown): TimelineKennel => {
  const row = asRecord(value);
  return {
    id: str(row.id),
    code: str(row.code),
    name: strOrNull(row.name),
    kennelTypeId: str(row.kennel_type_id),
    kennelTypeName: str(row.kennel_type_name),
    status: str(row.status) as KennelStatus,
    segments: Array.isArray(row.segments) ? row.segments.map(toSegment) : [],
  };
};

export const getBoardingTimeline = async (client: Client, branchId: string, from: string, days: number): Promise<BoardingTimeline> => {
  const result = asRecord(unwrap(await client.rpc("boarding_timeline", { p_branch: branchId, p_from: from, p_days: days })));
  return {
    from: str(result.from),
    days: Number(result.days ?? days),
    kennels: Array.isArray(result.kennels) ? result.kennels.map(toKennel) : [],
  };
};

export const moveBoardingPet = async (client: Client, stayPetId: string, kennelId: string): Promise<void> => {
  unwrap(await client.rpc("move_boarding_pet", { p_stay_pet: stayPetId, p_kennel: kennelId }));
};
