import type { Ref } from "vue";
import { toast } from "vue-sonner";
import { authErrorMessage } from "@/lib/auth-errors";
import type { AuthFlowContext } from "./types";

/** Password reset by emailed one-time code. */
export const createRecoveryFlow = (
  { supabase, loading, isSuccess, applySession }: AuthFlowContext,
  pendingRecoveryEmail: Ref<string | null>
) => {
  /** Emails a password-reset code (the email template carries the code, not a link). */
  async function sendResetPassMail(email: string) {
    loading.value = true;
    isSuccess.value = false;
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email);
      if (error) throw error;
      pendingRecoveryEmail.value = email;
      isSuccess.value = true;
      toast.success("We emailed you a code.");
    } catch (error) {
      toast.error(authErrorMessage(error));
    } finally {
      loading.value = false;
    }
  }

  async function resendRecoveryCode() {
    const email = pendingRecoveryEmail.value;
    if (!email) return;
    loading.value = true;
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email);
      if (error) throw error;
      toast.success("A new code has been sent.");
    } catch (error) {
      toast.error(authErrorMessage(error));
    } finally {
      loading.value = false;
    }
  }

  /** Checks the emailed code, then sets the new password and signs the user in. */
  async function resetPasswordWithCode({ code, password }: { code: string; password: string }) {
    const email = pendingRecoveryEmail.value;
    if (!email) return;
    loading.value = true;
    isSuccess.value = false;
    try {
      const { data, error } = await supabase.auth.verifyOtp({
        email,
        token: code.trim(),
        type: "recovery",
      });
      if (error) throw error;

      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) {
        // The code is single-use and was just spent: do not leave a half-recovered session.
        await supabase.auth.signOut({ scope: "local" });
        pendingRecoveryEmail.value = null;
        throw updateError;
      }

      await applySession(data.session);
      pendingRecoveryEmail.value = null;
      isSuccess.value = true;
      toast.success("Password updated.");
    } catch (error) {
      toast.error(authErrorMessage(error));
    } finally {
      loading.value = false;
    }
  }

  function cancelRecovery() {
    pendingRecoveryEmail.value = null;
  }

  return { sendResetPassMail, resendRecoveryCode, resetPasswordWithCode, cancelRecovery };
};
