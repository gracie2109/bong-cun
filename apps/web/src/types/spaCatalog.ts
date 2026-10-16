/** One weight bracket of a species (Dưới 5 kg, 5-10 kg...). `maxKg` null = no upper limit. */
export type SpaBracket = { id: string; label: string; minKg: number; maxKg: number | null };

export type SpaSpecies = { id: string; name: string; brackets: SpaBracket[] };

export type SpaServicePrice = { speciesId: string; bracketId: string; price: number };

/** A service on the public price list. `type` 'all' = one general price, 'by_weight' = price per bracket. */
export type SpaService = {
  id: string;
  name: string;
  description: string;
  type: "all" | "by_weight";
  durationMinutes: number | null;
  generalPrice: number | null;
  speciesIds: string[];
  prices: SpaServicePrice[];
};

export const SPA_COMBO_MARKS = ["1", "2", "3", "4"] as const;

export type SpaCombo = {
  id: string;
  name: string;
  description: string;
  price: number | null;
  originPrice: number | null;
  durationMinutes: number | null;
  /** '1' best seller, '2' new, '4' plain ('3' coming soon is never listed). */
  mark: string;
  speciesIds: string[];
  serviceNames: string[];
};

export type SpaCatalog = { species: SpaSpecies[]; services: SpaService[]; combos: SpaCombo[] };
