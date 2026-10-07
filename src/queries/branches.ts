import { useQuery } from "@tanstack/vue-query";
import { supabaseClient } from "@/lib/supabase";
import { listBranches } from "@/repositories/branches";
import { branchKeys } from "./keys";

export const useBranches = () =>
  useQuery({ queryKey: branchKeys.list(), queryFn: () => listBranches(supabaseClient()) });
