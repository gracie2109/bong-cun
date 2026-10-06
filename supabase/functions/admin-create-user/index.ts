// Creates an account on behalf of an admin. Needs the service role, so it cannot
// run in the browser. The old app wrote a raw password into Firestore from the
// client; here the password only ever goes to Supabase Auth.
//
// Caller must hold the `user_role` JWT claim `admin` or `superAdmin`. Only a
// superAdmin may create an account with a role other than `customer`.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const ADMIN_ROLES = ["admin", "superAdmin"];
const ROLES = ["customer", "admin", "superAdmin", "cashier"];
const GENDERS = ["MALE", "FEMALE", "OTHER"];

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const respond = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const fail = (status: number, code: string, message: string) =>
  respond(status, { error: { code, message } });

const isNonEmptyString = (value: unknown): value is string =>
  typeof value === "string" && value.trim().length > 0;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "method_not_allowed", "Use POST.");

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return fail(401, "unauthorized", "Missing bearer token.");

  const url = Deno.env.get("SUPABASE_URL")!;
  const callerClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: claimsData, error: claimsError } = await callerClient.auth.getClaims(
    authHeader.replace("Bearer ", ""),
  );
  if (claimsError || !claimsData?.claims) return fail(401, "unauthorized", "Invalid token.");

  const callerRole = (claimsData.claims as { user_role?: string }).user_role ?? "";
  if (!ADMIN_ROLES.includes(callerRole)) return fail(403, "forbidden", "Admin role required.");

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail(400, "invalid_body", "Body must be JSON.");
  }

  const { email, password, displayName, fullName, phoneNumber, gender, address, photoURL } = body;
  const role = (body.role as string | undefined) ?? "customer";

  if (!isNonEmptyString(email) || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return fail(400, "invalid_email", "A valid email is required.");
  }
  if (typeof password !== "string" || password.length < 8) {
    return fail(400, "invalid_password", "Password must be at least 8 characters.");
  }
  if (!isNonEmptyString(displayName) || displayName.trim().length < 3) {
    return fail(400, "invalid_display_name", "Display name must be at least 3 characters.");
  }
  if (gender !== undefined && gender !== null && !GENDERS.includes(gender as string)) {
    return fail(400, "invalid_gender", "Gender must be MALE, FEMALE or OTHER.");
  }
  if (!ROLES.includes(role)) return fail(400, "invalid_role", "Unknown role.");
  if (role !== "customer" && callerRole !== "superAdmin") {
    return fail(403, "forbidden", "Only a superAdmin can assign a role.");
  }

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Friendly uniqueness errors; the unique constraints remain the real guard.
  const { data: nameTaken } = await admin
    .from("users").select("id").ilike("display_name", displayName.trim()).maybeSingle();
  if (nameTaken) return fail(409, "display_name_taken", "Display name already exists.");

  if (isNonEmptyString(phoneNumber)) {
    const { data: phoneTaken } = await admin
      .from("users").select("id").eq("phone_number", phoneNumber).maybeSingle();
    if (phoneTaken) return fail(409, "phone_taken", "Phone number already exists.");
  }

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      display_name: displayName.trim(),
      ...(isNonEmptyString(fullName) ? { full_name: fullName } : {}),
    },
  });
  if (createError || !created.user) {
    const code = createError?.code ?? "create_failed";
    const status = code === "email_exists" ? 409 : 400;
    return fail(status, code, code === "email_exists" ? "Email already exists." : "Could not create the user.");
  }

  // The signup trigger already inserted the users row; complete it. The service
  // role has no JWT uid, so the column guard trigger lets the role be set.
  const { error: updateError } = await admin
    .from("users")
    .update({
      role,
      full_name: isNonEmptyString(fullName) ? fullName : null,
      phone_number: isNonEmptyString(phoneNumber) ? phoneNumber : null,
      gender: (gender as string | null | undefined) ?? null,
      address: (address as Record<string, unknown> | null | undefined) ?? null,
      photo_url: isNonEmptyString(photoURL) ? photoURL : null,
    })
    .eq("id", created.user.id);

  if (updateError) {
    await admin.auth.admin.deleteUser(created.user.id); // do not leave a half-created account
    return fail(409, "profile_conflict", "Could not save the user profile.");
  }

  return respond(201, { id: created.user.id });
});
