// The public pet hotel page (boarding_public_catalog): readable without signing in.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import type { BoardingWebCatalog } from "@/types/boardingWeb";
import { unwrap } from "../shared";

type Client = SupabaseClient<Database>;

type CatalogJson = {
  branch: { id: string; name: string; phone: string | null } | null;
  rules: { check_in_from: string; check_out_by: string; late_half_until: string } | null;
  kennel_types: {
    id: string;
    name: string;
    description: string | null;
    photo_url: string | null;
    max_weight_kg: number | null;
    max_pets: number;
    night_price: number;
    extra_pet_night_price: number | null;
    species: string[];
  }[];
};

export const getBoardingPublicCatalog = async (client: Client, branchId: string | null = null): Promise<BoardingWebCatalog> => {
  const json = unwrap(await client.rpc("boarding_public_catalog", { p_branch: branchId })) as CatalogJson;
  return {
    branch: json.branch && { id: json.branch.id, name: json.branch.name, phone: json.branch.phone ?? "" },
    rules: json.rules && {
      checkInFrom: json.rules.check_in_from,
      checkOutBy: json.rules.check_out_by,
      lateHalfUntil: json.rules.late_half_until,
    },
    kennelTypes: json.kennel_types.map((type) => ({
      id: type.id,
      name: type.name,
      description: type.description ?? "",
      photoUrl: type.photo_url,
      maxWeightKg: type.max_weight_kg === null ? null : Number(type.max_weight_kg),
      maxPets: Number(type.max_pets),
      nightPrice: Number(type.night_price),
      extraPetNightPrice: type.extra_pet_night_price === null ? null : Number(type.extra_pet_night_price),
      species: type.species,
    })),
  };
};
