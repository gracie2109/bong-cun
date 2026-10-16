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

export const USER_SORT = {
  NEWEST: "newest",
  OLDEST: "oldest",
  NAME: "name",
} as const;
export type UserSort = (typeof USER_SORT)[keyof typeof USER_SORT];

export type UserListFilter = {
  role?: string;
  /** Matched against display name, full name, email and phone number. */
  search?: string;
  /** ISO timestamp: only accounts created at or after it. */
  createdSince?: string;
  sort?: UserSort;
};

const SEARCH_COLUMNS = ["display_name", "full_name", "email", "phone_number"] as const;

/** Double-quoted so commas/parentheses in the term cannot break the PostgREST `or` syntax. */
const searchFilter = (term: string) => {
  const quoted = `"%${term.replace(/[\\"]/g, "\\$&")}%"`;
  return SEARCH_COLUMNS.map((column) => `${column}.ilike.${quoted}`).join(",");
};

type Filterable<Q> = {
  eq: (column: string, value: string) => Q;
  gte: (column: string, value: string) => Q;
  or: (filters: string) => Q;
};

const applyUserFilter = <Q extends Filterable<Q>>(query: Q, filter: UserListFilter): Q => {
  let next = query;
  if (filter.role) next = next.eq("role", filter.role);
  if (filter.createdSince) next = next.gte("created_at", filter.createdSince);
  const term = filter.search?.trim();
  if (term) next = next.or(searchFilter(term));
  return next;
};

export const listUsers = async (
  client: Client,
  page: PageParams,
  filter: UserListFilter = {}
): Promise<Page<IUser>> => {
  const { from, to } = pageRange(page);
  let query = applyUserFilter(client.from("users").select("*", { count: "exact" }), filter);
  query =
    filter.sort === USER_SORT.NAME
      ? query.order("full_name", { ascending: true, nullsFirst: false })
      : query.order("created_at", { ascending: filter.sort === USER_SORT.OLDEST });

  const { data, count, error } = await query.range(from, to);
  if (error) throw error;
  return { rows: (data ?? []).map(toCurrentUser), total: count ?? 0 };
};

export const countUsers = async (client: Client, filter: UserListFilter = {}): Promise<number> => {
  const { count, error } = await applyUserFilter(
    client.from("users").select("id", { count: "exact", head: true }),
    filter
  );
  if (error) throw error;
  return count ?? 0;
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
