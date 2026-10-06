// Maps Supabase Auth error codes to user-facing messages. Pure TS (no toast, no
// i18n) so it is reusable on a Nuxt server route as well as in the browser.
type AuthErrorLike = { code?: string; message?: string };

const isAuthErrorLike = (error: unknown): error is AuthErrorLike =>
  typeof error === "object" && error !== null && ("code" in error || "message" in error);

export const hasAuthCode = (error: unknown, code: string): boolean =>
  isAuthErrorLike(error) && error.code === code;

export const authErrorMessage = (error: unknown): string => {
  if (!isAuthErrorLike(error)) return "Something went wrong.";

  switch (error.code) {
    case "user_already_exists":
    case "email_exists":
      return "Email already exists.";
    case "weak_password":
      return "Password is too weak.";
    case "invalid_credentials":
      return "Email or password is incorrect.";
    case "email_not_confirmed":
      return "Please verify your email before logging in.";
    case "otp_expired":
      return "The code is invalid or has expired.";
    case "over_email_send_rate_limit":
    case "over_request_rate_limit":
      return "Too many requests. Please try again later.";
    default:
      return error.message ?? "Something went wrong.";
  }
};
