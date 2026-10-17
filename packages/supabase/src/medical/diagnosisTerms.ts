// The diagnosis catalog shared by every branch.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { diagnosisTermPageSchema } from "@bongcun/core/medical";
import type { DiagnosisTerm, DiagnosisTermFilter, DiagnosisTermInput } from "@bongcun/core/medical";
import { parseRpc, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { toDiagnosisTerm } from "./mappers";

type Client = SupabaseClient<Database>;

export const listDiagnosisTerms = async (
  client: Client,
  page: PageParams,
  filter: DiagnosisTermFilter = {}
): Promise<Page<DiagnosisTerm>> => {
  const raw = unwrap(
    await client.rpc("list_diagnosis_terms", {
      p_search: filter.search?.trim() || undefined,
      p_species: filter.speciesId || undefined,
      p_page: page.pageIndex,
      p_page_size: page.pageSize,
      p_active_only: filter.activeOnly ?? false,
    })
  );
  const result = parseRpc("list_diagnosis_terms", diagnosisTermPageSchema, raw);
  return { rows: (result.rows ?? []).map(toDiagnosisTerm), total: result.total };
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
