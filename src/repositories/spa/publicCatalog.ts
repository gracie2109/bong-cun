// The public spa price list (spa_public_catalog): readable without signing in.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import type { SpaCatalog } from "@/types/spaCatalog";
import { unwrap } from "../shared";

type Client = SupabaseClient<Database>;

type CatalogJson = {
  species: { id: string; name: string; brackets: { id: string; label: string; min_kg: number; max_kg: number | null }[] }[];
  services: {
    id: string;
    name: string;
    description: string | null;
    type: string;
    duration_minutes: number | null;
    general_price: number | null;
    species_ids: string[];
    prices: { species_id: string; bracket_id: string; price: number }[];
  }[];
  combos: {
    id: string;
    name: string;
    description: string | null;
    price: number | null;
    origin_price: number | null;
    duration_minutes: number | null;
    mark: string | null;
    species_ids: string[];
    service_names: string[];
  }[];
};

const num = (value: number | null): number | null => (value === null ? null : Number(value));

export const toSpaCatalog = (json: CatalogJson): SpaCatalog => ({
  species: json.species.map((item) => ({
    id: item.id,
    name: item.name,
    brackets: item.brackets.map((b) => ({ id: b.id, label: b.label, minKg: Number(b.min_kg), maxKg: num(b.max_kg) })),
  })),
  services: json.services.map((item) => ({
    id: item.id,
    name: item.name,
    description: item.description ?? "",
    type: item.type === "by_weight" ? "by_weight" : "all",
    durationMinutes: item.duration_minutes,
    generalPrice: num(item.general_price),
    speciesIds: item.species_ids,
    prices: item.prices.map((p) => ({ speciesId: p.species_id, bracketId: p.bracket_id, price: Number(p.price) })),
  })),
  combos: json.combos.map((item) => ({
    id: item.id,
    name: item.name,
    description: item.description ?? "",
    price: num(item.price),
    originPrice: num(item.origin_price),
    durationMinutes: item.duration_minutes,
    mark: item.mark ?? "4",
    speciesIds: item.species_ids,
    serviceNames: item.service_names,
  })),
});

export const getSpaPublicCatalog = async (client: Client, branchId: string | null): Promise<SpaCatalog> =>
  toSpaCatalog(unwrap(await client.rpc("spa_public_catalog", { p_branch: branchId })) as CatalogJson);
