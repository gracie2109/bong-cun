import { computed, ref, shallowRef, type Ref } from "vue";
import { defineStore } from "pinia";
import type { AuthSession } from "@bongcun/supabase/shared";
import { toast } from "vue-sonner";
import { useRoute, useRouter } from "vue-router";
import { supabaseClient } from "@/lib/supabase";
import {
  getUserById,
  isDisplayNameAvailable,
  toCurrentUser,
} from "@bongcun/supabase/users";
import { isAdminRole, isStaffRole } from "@bongcun/core/auth";
import { authErrorMessage, hasAuthCode } from "@/lib/auth-errors";
import { removeStorage, sendMessageToast } from "@/lib/utils";
import type { IUser, ILoginPayload, IRegisterPayload } from "@bongcun/core/users";
import { createAdminGrants } from "./auth-parts/adminGrants";
import { createRecoveryFlow } from "./auth-parts/recovery";
import { createVerificationFlow } from "./auth-parts/verification";

export const useAuthStore = defineStore("auth", () => {
  const supabase = supabaseClient();
  const users: Ref<IUser[]> = ref([]);
  const currentUser = ref<IUser | null>(null);
  const session = shallowRef<AuthSession | null>(null);
  // Role comes from the signed JWT claim `user_role` (set by the Custom Access
  // Token Hook), the same value Row Level Security policies read.
  const role = ref<string | null>(null);
  const loading = ref(false);
  const isSuccess = ref(false);
  // Set while an account is waiting for its emailed one-time code. The views
  // show the code form for as long as this is non-null.
  const pendingVerificationEmail = ref<string | null>(null);
  // Same idea for a password reset: the code form shows while this is non-null.
  const pendingRecoveryEmail = ref<string | null>(null);
  const route = useRoute();
  const router = useRouter();

  const isAuthenticated = computed(() => !!session.value);
  const isAdmin = computed(() => isAdminRole(role.value));
  const isStaff = computed(() => isStaffRole(role.value));

  const { adminGrants, loadAdminGrants, can } = createAdminGrants({
    supabase,
    session,
    role,
    whenSessionApplied: () => applyPromise,
  });

  // ---------------------------------------------------------------- session
  // `undefined` = never applied. Applying the same access token twice returns
  // the in-flight promise, so login() and the onAuthStateChange event do not
  // both load the user, and init() can wait for the load to finish.
  let appliedToken: string | null | undefined;
  let applyPromise: Promise<void> = Promise.resolve();

  async function loadUser(next: AuthSession | null, token: string | null) {
    if (!next) {
      role.value = null;
      currentUser.value = null;
      return;
    }
    try {
      const [claims, row] = await Promise.all([
        supabase.auth.getClaims(next.access_token),
        getUserById(supabase, next.user.id),
      ]);
      if (appliedToken !== token) return; // a newer session superseded this one
      const claim = claims.data?.claims as { user_role?: string } | undefined;
      role.value = claim?.user_role ?? null;
      currentUser.value = row ? toCurrentUser(row) : null;
    } catch (error) {
      console.error("Failed to load user", error);
    }
  }

  function applySession(next: AuthSession | null) {
    const token = next?.access_token ?? null;
    session.value = next;
    if (token === appliedToken) return applyPromise;
    appliedToken = token;
    applyPromise = loadUser(next, token);
    return applyPromise;
  }

  let initPromise: Promise<void> | null = null;
  /** Restores the session once and subscribes to auth changes. Safe to call repeatedly. */
  function init() {
    if (!initPromise) {
      initPromise = (async () => {
        // The server builds a fresh store per request, so it only reads the
        // session from the request cookies and never subscribes.
        if (import.meta.client) {
          supabase.auth.onAuthStateChange((_event, next) => {
            // Never await Supabase calls inside this callback (it can deadlock the
            // client), so the work is deferred out of it.
            setTimeout(() => void applySession(next), 0);
          });
        }
        const { data } = await supabase.auth.getSession();
        await applySession(data.session);
      })();
    }
    return initPromise;
  }

  const flowContext = { supabase, loading, isSuccess, applySession };
  const { startVerification, verifyEmailCode, resendVerificationCode, cancelVerification } =
    createVerificationFlow(flowContext, pendingVerificationEmail);
  const { sendResetPassMail, resendRecoveryCode, resetPasswordWithCode, cancelRecovery } =
    createRecoveryFlow(flowContext, pendingRecoveryEmail);

  // ------------------------------------------------------------------ actions
  async function signUp(payload: IRegisterPayload | IUser) {
    loading.value = true;
    isSuccess.value = false;
    try {
      const available = await isDisplayNameAvailable(supabase, payload.displayName);
      if (!available) {
        toast.error("Display name already exists.");
        return;
      }

      // The database trigger copies this account into public.users with the
      // default role. The role is never taken from client-supplied metadata.
      const { data, error } = await supabase.auth.signUp({
        email: payload.email,
        password: payload.password,
        options: {
          data: { display_name: payload.displayName },
        },
      });
      if (error) throw error;

      // With email enumeration protection, an existing address comes back as a
      // user with no identities instead of an error.
      if (data.user && data.user.identities?.length === 0) {
        toast.error("Email already exists.");
        return;
      }

      if (data.session) {
        isSuccess.value = true;
        sendMessageToast("success", "create", "success");
      } else {
        // Email confirmation is on: Supabase has emailed a one-time code.
        pendingVerificationEmail.value = payload.email;
        toast.success("Account created. Enter the code we emailed you to verify it.");
      }
    } catch (error) {
      toast.error(authErrorMessage(error));
    } finally {
      loading.value = false;
    }
  }

  async function login(payload: ILoginPayload) {
    loading.value = true;
    isSuccess.value = false;
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: payload.email,
        password: payload.password,
      });
      if (error) throw error;

      await applySession(data.session);
      if (!currentUser.value) {
        await supabase.auth.signOut({ scope: "local" });
        toast.error("User not found.");
        return;
      }
      isSuccess.value = true;
    } catch (error) {
      if (hasAuthCode(error, "email_not_confirmed")) {
        await startVerification(payload.email);
      } else {
        toast.error(authErrorMessage(error));
      }
    } finally {
      loading.value = false;
    }
  }

  async function loginGoogle() {
    loading.value = true;
    // OAuth is a full-page redirect, not a popup. The session is picked up by
    // init() when the browser comes back, so isSuccess stays false here.
    isSuccess.value = false;
    try {
      const { error } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: { redirectTo: window.location.origin },
      });
      if (error) throw error;
    } catch (error) {
      toast.error(authErrorMessage(error));
      loading.value = false;
    }
  }

  /** Attaches a Google identity to the signed-in account (full-page redirect). */
  async function linkGoogleIdentity() {
    const { error } = await supabase.auth.linkIdentity({
      provider: "google",
      options: { redirectTo: window.location.href },
    });
    if (error) toast.error(authErrorMessage(error));
  }

  async function getListUsers() {
    try {
      loading.value = true;
    } catch (error) {
      console.log("error", error);
    } finally {
      loading.value = false;
    }
  }

  async function signoutHdl() {
    // Local scope: sign out this device only, not every session of the account.
    await supabase.auth.signOut({ scope: "local" });
    await applySession(null);
    removeStorage([]);
    if (route.fullPath?.includes("admin")) {
      setTimeout(() => router.push("/"), 1000);
    } else {
      router.go(0);
    }
    toast.success("Logout success!");
  }

  return {
    loading,
    signUp,
    getListUsers,
    sendResetPassMail,
    resendRecoveryCode,
    resetPasswordWithCode,
    cancelRecovery,
    pendingRecoveryEmail,
    users,
    login,
    currentUser,
    isSuccess,
    signoutHdl,
    loginGoogle,
    linkGoogleIdentity,
    session,
    role,
    isAuthenticated,
    isAdmin,
    isStaff,
    adminGrants,
    loadAdminGrants,
    can,
    init,
    pendingVerificationEmail,
    verifyEmailCode,
    resendVerificationCode,
    cancelVerification,
  };
});
