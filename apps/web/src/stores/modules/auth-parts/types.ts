import type { Ref } from "vue";
import type { AuthSession, DbClient } from "@bongcun/supabase/shared";

/** The store state the verification and recovery flows read and write. */
export type AuthFlowContext = {
  supabase: DbClient;
  loading: Ref<boolean>;
  isSuccess: Ref<boolean>;
  applySession: (next: AuthSession | null) => Promise<void>;
};
