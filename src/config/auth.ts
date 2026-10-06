// Client-side auth constants, shared by the code-entry forms (email verification
// and password reset). Server-side auth settings (OTP length and expiry, email
// templates, redirect URLs, the access-token hook) live in supabase/config.toml.

/** Accepted length of an emailed one-time code (Supabase allows 6 to 10 digits). */
export const OTP_CODE_PATTERN = /^\d{6,10}$/;

/** How long "resend code" stays disabled after a code was just sent. */
export const OTP_RESEND_COOLDOWN_SECONDS = 60;
