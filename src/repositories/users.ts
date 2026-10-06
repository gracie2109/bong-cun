// Pure data access for the `users` table. Takes a client, imports nothing from
// Vue/Pinia/router/env, so it runs unchanged in Nuxt (client or server).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { IROLE } from "@/types";
import type { Database, Tables } from "@/types/database.types";
import type { IAddress } from "@/types/location.type";
import { initAddress, type IUser } from "@/types/user.type";
import { pageRange, type Page, type PageParams } from "./shared";

type Client = SupabaseClient<Database>;
export type UserRow = Tables<"users">;

export const getUserById = async (
  client: Client,
  id: string
): Promise<UserRow | null> => {
  const { data, error } = await client
    .from("users")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (error) throw error;
  return data;
};

export const isDisplayNameAvailable = async (
  client: Client,
  displayName: string
): Promise<boolean> => {
  const { data, error } = await client.rpc("is_display_name_available", {
    p_display_name: displayName,
  });
  if (error) throw error;
  return data;
};

// Existing screens read the legacy IUser shape (userId, displayName,
// photoURL, phoneNumber), so the mapper keeps it stable while the data layer
// underneath changes.
export const toCurrentUser = (row: UserRow): IUser => {
  const email = row.email ?? "";
  const displayName = row.display_name ?? row.full_name ?? email.split("@")[0];
  return {
    userId: row.id,
    email,
    displayName,
    userName: row.display_name ?? "",
    fullName: row.full_name ?? undefined,
    phoneNumber: row.phone_number ?? undefined,
    photoURL: row.photo_url ?? undefined,
    gender: row.gender ?? undefined,
    role: row.role as IROLE,
    province: (row.address as IAddress | null) ?? initAddress,
    available_id: null,
    isActive: true,
    password: "",
    groupIds: null,
    shipping_address: { providerId: "supabase", email, displayName },
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

export const listUsers = async (
  client: Client,
  page: PageParams,
  filter: { role?: string } = {}
): Promise<Page<IUser>> => {
  const { from, to } = pageRange(page);
  let query = client
    .from("users")
    .select("*", { count: "exact" })
    .order("created_at", { ascending: false })
    .range(from, to);
  if (filter.role) query = query.eq("role", filter.role);

  const { data, count, error } = await query;
  if (error) throw error;
  return { rows: (data ?? []).map(toCurrentUser), total: count ?? 0 };
};

export type CreateUserInput = {
  email: string;
  password: string;
  displayName: string;
  fullName?: string | null;
  phoneNumber?: string | null;
  gender?: string | null;
  address?: IAddress | null;
  photoURL?: string | null;
  /** Only a superAdmin may set a role other than "customer". */
  role?: IROLE;
};

/** Error reported by the admin-create-user Edge Function (`code` is its error code). */
export class UserFunctionError extends Error {
  constructor(
    public readonly code: string,
    message: string
  ) {
    super(message);
    this.name = "UserFunctionError";
  }
}

/**
 * Creates an account for someone else. Needs the service role, so it goes
 * through the admin-create-user Edge Function (which checks the caller is an
 * admin); the password never touches a table.
 */
export const createUserAsAdmin = async (
  client: Client,
  input: CreateUserInput
): Promise<string> => {
  const { data, error } = await client.functions.invoke<{ id: string }>("admin-create-user", {
    body: input,
  });

  if (error) {
    // Duck-typed instead of `instanceof FunctionsHttpError`: that check breaks when
    // two copies of the library are loaded (bundlers, SSR). `context` is the Response.
    const response = (error as { context?: Response }).context;
    if (error.name === "FunctionsHttpError" && typeof response?.json === "function") {
      const body = (await response.json().catch(() => null)) as {
        error?: { code?: string; message?: string };
      } | null;
      throw new UserFunctionError(
        body?.error?.code ?? "unknown",
        body?.error?.message ?? error.message
      );
    }
    throw error;
  }
  return (data as { id: string }).id;
};
