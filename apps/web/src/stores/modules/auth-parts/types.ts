import type { Ref } from "vue";
import type { Session, SupabaseClient } from "@supabase/supabase-js";

/** The store state the verification and recovery flows read and write. */
export type AuthFlowContext = {
  supabase: SupabaseClient;
  loading: Ref<boolean>;
  isSuccess: Ref<boolean>;
  applySession: (next: Session | null) => Promise<void>;
};
