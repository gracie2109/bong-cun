import { useQuery } from "@tanstack/vue-query";
import { supabaseClient } from "@/lib/supabase";
import { listBranches } from "@bongcun/supabase/users";
import { branchKeys } from "./keys";

export const useBranches = () =>
  useQuery({ queryKey: branchKeys.list(), queryFn: () => listBranches(supabaseClient()) });
