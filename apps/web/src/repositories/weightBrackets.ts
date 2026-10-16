// Weight brackets of a species: [minKg, maxKg) ranges that decide the spa price of a pet.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;

export type WeightBracket = {
  id: string;
  speciesId: string;
  label: string;
  minKg: number;
  /** null = no upper limit. */
  maxKg: number | null;
  sortOrder: number;
};

/** A bracket row as edited in the form; new rows have no id yet. */
export type WeightBracketInput = {
  id?: string;
  label: string;
  minKg: number;
  maxKg: number | null;
};

export const toWeightBracket = (row: Tables<"weight_brackets">): WeightBracket => ({
  id: row.id,
  speciesId: row.species_id,
  label: row.label,
  minKg: row.min_kg,
  maxKg: row.max_kg,
  sortOrder: row.sort_order,
});

export const listWeightBrackets = async (
  client: Client,
  speciesId?: string
): Promise<WeightBracket[]> => {
  let query = client.from("weight_brackets").select("*").order("min_kg");
  if (speciesId) query = query.eq("species_id", speciesId);
  return unwrap(await query).map(toWeightBracket);
};

/** Replaces all brackets of a species in one transaction; a bracket left out is deleted with its prices. */
export const saveWeightBrackets = async (
  client: Client,
  speciesId: string,
  rows: WeightBracketInput[]
): Promise<void> => {
  const { error } = await client.rpc("save_weight_brackets", {
    p_species_id: speciesId,
    p_rows: rows.map((row) => ({
      id: row.id ?? null,
      label: row.label,
      min_kg: row.minKg,
      max_kg: row.maxKg,
    })),
  });
  if (error) throw error;
};

export type BracketIssue =
  | { type: "overlap"; first: string; second: string }
  | { type: "gap"; fromKg: number; toKg: number }
  | { type: "invalid"; label: string };

/** Problems the form shows before saving: overlaps and invalid ranges block, gaps only warn. */
export const checkBrackets = (rows: WeightBracketInput[]): BracketIssue[] => {
  const issues: BracketIssue[] = [];
  const sorted = [...rows].sort((a, b) => a.minKg - b.minKg);

  for (const row of sorted) {
    if (row.maxKg !== null && row.maxKg <= row.minKg) issues.push({ type: "invalid", label: row.label });
  }
  sorted.forEach((row, index) => {
    const next = sorted[index + 1];
    if (!next) return;
    if (row.maxKg === null || row.maxKg > next.minKg) {
      issues.push({ type: "overlap", first: row.label, second: next.label });
    } else if (row.maxKg < next.minKg) {
      issues.push({ type: "gap", fromKg: row.maxKg, toKg: next.minKg });
    }
  });
  return issues;
};

/** The bracket a weight falls into, or undefined when no bracket covers it. */
export const findBracket = (brackets: WeightBracket[], weightKg: number): WeightBracket | undefined =>
  brackets.find(
    (bracket) => weightKg >= bracket.minKg && (bracket.maxKg === null || weightKg < bracket.maxKg)
  );
