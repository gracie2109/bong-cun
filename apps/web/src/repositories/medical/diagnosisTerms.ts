// The diagnosis catalog shared by every branch.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { DiagnosisTerm, DiagnosisTermFilter, DiagnosisTermInput } from "@/types/medical";
import { unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { asRecord, str } from "../spa/parse";

type Client = SupabaseClient<Database>;

const strings = (value: unknown): string[] => (Array.isArray(value) ? value.map(String) : []);

const toDiagnosisTerm = (value: unknown): DiagnosisTerm => {
  const row = asRecord(value);
  return {
    id: str(row.id),
    name: str(row.name),
    speciesIds: strings(row.species_ids),
    speciesNames: strings(row.species_names),
    isContagious: row.is_contagious === true,
    isActive: row.is_active === true,
    sortOrder: Number(row.sort_order ?? 0),
  };
};

export const listDiagnosisTerms = async (
  client: Client,
  page: PageParams,
  filter: DiagnosisTermFilter = {}
): Promise<Page<DiagnosisTerm>> => {
  const result = asRecord(
    unwrap(
      await client.rpc("list_diagnosis_terms", {
        p_search: filter.search?.trim() || undefined,
        p_species: filter.speciesId || undefined,
        p_page: page.pageIndex,
        p_page_size: page.pageSize,
        p_active_only: filter.activeOnly ?? false,
      })
    )
  );
  const rows = Array.isArray(result.rows) ? result.rows : [];
  return { rows: rows.map(toDiagnosisTerm), total: Number(result.total ?? 0) };
};

export const saveDiagnosisTerm = async (client: Client, input: DiagnosisTermInput, id?: string): Promise<string> =>
  unwrap(
    await client.rpc("save_diagnosis_term", {
      p: {
        name: input.name,
        species_ids: input.speciesIds,
        is_contagious: input.isContagious,
        is_active: input.isActive,
        sort_order: input.sortOrder,
      },
      p_id: id,
    })
  );
