// Roles are keyed by `name` in the database; `id` is the name. The permissions a
// role grants keep the shape the role form already uses:
// [{ id: <permission name>, method: ['CREATE', 'VIEW', ...] }].
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;
type RoleRow = Tables<"roles"> & {
  role_permissions: { permission: string; methods: string[] }[];
  staff_branches: { count: number }[];
};

export type RolePermissionGrant = { id: string; method: string[] };

export type Role = {
  id: string;
  name: string;
  description: string | null;
  /** superAdmin and customer: cannot be renamed or deleted. */
  isSystem: boolean;
  permissions: RolePermissionGrant[];
  /** Number of (staff, branch) assignments holding this role. */
  staffCount: number;
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
  isSystem: row.is_system,
  permissions: row.role_permissions.map((grant) => ({
    id: grant.permission,
    method: grant.methods,
  })),
  staffCount: row.staff_branches[0]?.count ?? 0,
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
      .select("*, role_permissions(permission, methods), staff_branches(count)")
      .order("is_system", { ascending: false })
      .order("created_at")
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
