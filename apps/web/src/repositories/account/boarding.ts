// "My boarding stays": the customer's pet hotel stays, read through RPCs (docs/khach-san-thu-cung.md, 7).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { BoardingScope, MyBoardingCharge, MyBoardingDetail, MyBoardingLog, MyBoardingPet, MyBoardingStay } from "@/types/account";
import { unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

type PetJson = {
  pet_name: string | null;
  status: string;
  kennel_type_name: string;
  nights_from: string;
  nights_to: string;
  charged_nights: number;
  feeding: string | null;
  medication: string | null;
};

type StayJson = {
  id: string;
  code: string;
  status: string;
  planned_in_at: string;
  planned_out_at: string;
  checked_in_at: string | null;
  checked_out_at: string | null;
  branch_name: string;
  branch_phone: string | null;
  est_total: number;
  is_final: boolean;
  pets: PetJson[];
};

type DetailJson = StayJson & {
  care_logs: { id: string; pet_name: string | null; kind: string; meal_eaten: string | null; content: string | null; logged_at: string }[];
  charges: { id: string; pet_name: string | null; kind: string; name: string; qty: number; unit_price: number; amount: number }[];
};

const toPet = (row: PetJson): MyBoardingPet => ({
  petName: row.pet_name ?? "",
  status: row.status,
  kennelTypeName: row.kennel_type_name,
  nightsFrom: row.nights_from,
  nightsTo: row.nights_to,
  chargedNights: Number(row.charged_nights),
  feeding: row.feeding ?? "",
  medication: row.medication ?? "",
});

const toStay = (row: StayJson): MyBoardingStay => ({
  id: row.id,
  code: row.code,
  status: row.status,
  plannedInAt: row.planned_in_at,
  plannedOutAt: row.planned_out_at,
  checkedInAt: row.checked_in_at,
  checkedOutAt: row.checked_out_at,
  branchName: row.branch_name,
  branchPhone: row.branch_phone ?? "",
  estTotal: Number(row.est_total),
  isFinal: row.is_final,
  pets: row.pets.map(toPet),
});

const toLog = (row: DetailJson["care_logs"][number]): MyBoardingLog => ({
  id: row.id,
  petName: row.pet_name ?? "",
  kind: row.kind,
  mealEaten: row.meal_eaten,
  content: row.content ?? "",
  loggedAt: row.logged_at,
});

const toCharge = (row: DetailJson["charges"][number]): MyBoardingCharge => ({
  id: row.id,
  petName: row.pet_name ?? "",
  kind: row.kind,
  name: row.name,
  qty: Number(row.qty),
  unitPrice: Number(row.unit_price),
  amount: Number(row.amount),
});

export type MyBoardingPage = { total: number; rows: MyBoardingStay[] };

export const listMyBoardingStays = async (
  client: Client,
  scope: BoardingScope,
  page: number,
  pageSize: number
): Promise<MyBoardingPage> => {
  const json = unwrap(await client.rpc("my_boarding_stays", { p_scope: scope, p_page: page, p_page_size: pageSize })) as {
    total: number;
    rows: StayJson[];
  };
  return { total: Number(json.total), rows: json.rows.map(toStay) };
};

export const getMyBoardingStay = async (client: Client, id: string): Promise<MyBoardingDetail> => {
  const json = unwrap(await client.rpc("my_boarding_stay", { p_id: id })) as DetailJson;
  return { ...toStay(json), careLogs: json.care_logs.map(toLog), charges: json.charges.map(toCharge) };
};
