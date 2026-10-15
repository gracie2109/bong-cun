import type { Ref } from "vue";
import { toast } from "vue-sonner";
import { authErrorMessage } from "@/lib/auth-errors";
import type { AuthFlowContext } from "./types";

/** Emailed one-time code flow for new accounts that are not verified yet. */
export const createVerificationFlow = (
  { supabase, loading, isSuccess, applySession }: AuthFlowContext,
  pendingVerificationEmail: Ref<string | null>
) => {
  /** Sends a fresh code to an unverified account and switches the UI to the code form. */
  async function startVerification(email: string) {
    pendingVerificationEmail.value = email;
    const { error } = await supabase.auth.resend({ type: "signup", email });
    if (error) {
      toast.error(authErrorMessage(error));
    } else {
      toast.info("Please verify your email. We sent you a code.");
    }
  }

  async function verifyEmailCode(code: string) {
    const email = pendingVerificationEmail.value;
    if (!email) return;
    loading.value = true;
    isSuccess.value = false;
    try {
      const { data, error } = await supabase.auth.verifyOtp({
        email,
        token: code.trim(),
        type: "signup",
      });
      if (error) throw error;

      await applySession(data.session);
      pendingVerificationEmail.value = null;
      isSuccess.value = true;
      toast.success("Email verified.");
    } catch (error) {
      toast.error(authErrorMessage(error));
    } finally {
      loading.value = false;
    }
  }

  async function resendVerificationCode() {
    const email = pendingVerificationEmail.value;
    if (!email) return;
    loading.value = true;
    try {
      const { error } = await supabase.auth.resend({ type: "signup", email });
      if (error) throw error;
      toast.success("A new code has been sent.");
    } catch (error) {
      toast.error(authErrorMessage(error));
    } finally {
      loading.value = false;
    }
  }

  function cancelVerification() {
    pendingVerificationEmail.value = null;
  }

  return { startVerification, verifyEmailCode, resendVerificationCode, cancelVerification };
};
