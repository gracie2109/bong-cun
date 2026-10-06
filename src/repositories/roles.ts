// Roles are keyed by `name` in the database; `id` is the name. The permissions a
// role grants keep the shape the role form already uses:
// [{ id: <permission name>, method: ['CREATE', 'VIEW', ...] }].
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;
type RoleRow = Tables<"roles"> & {
  role_permissions: { permission: string; methods: string[] }[];
};

export type RolePermissionGrant = { id: string; method: string[] };

export type Role = {
  id: string;
  name: string;
  description: string | null;
  permissions: RolePermissionGrant[];
  createdAt: string;
};

export type RoleInput = {
  name: string;
  description?: string | null;
  permissions?: RolePermissionGrant[] | null;
};

const toRole = (row: RoleRow): Role => ({
  id: row.name,
  name: row.name,
  description: row.description,
  permissions: row.role_permissions.map((grant) => ({
    id: grant.permission,
    method: grant.methods,
  })),
  createdAt: row.created_at,
});

const toRpcPayload = (input: RoleInput) => ({
  name: input.name,
  description: input.description ?? null,
  permissions: (input.permissions ?? []).map((grant) => ({ id: grant.id, methods: grant.method })),
});

export const listRoles = async (client: Client): Promise<Role[]> => {
  const rows = unwrap(
    await client
      .from("roles")
      .select("*, role_permissions(permission, methods)")
      .order("created_at", { ascending: false })
  );
  return (rows as RoleRow[]).map(toRole);
};

export const createRole = async (client: Client, input: RoleInput): Promise<string> =>
  unwrap(await client.rpc("save_role", { p: toRpcPayload(input) }));

export const updateRole = async (client: Client, id: string, input: RoleInput): Promise<string> =>
  unwrap(await client.rpc("save_role", { p: toRpcPayload(input), p_id: id }));

export const deleteRole = async (client: Client, id: string): Promise<void> => {
  const { error } = await client.from("roles").delete().eq("name", id);
  if (error) throw error;
};
