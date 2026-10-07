// Permissions are keyed by `name` in the database; the admin screens expect an
// `id`, so `id` is the name.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;

export type Permission = {
  id: string;
  name: string;
  methods: string[];
  description: string | null;
  /** Group shown on the permission screens, e.g. "Bán hàng". */
  module: string | null;
  sortOrder: number;
  createdAt: string;
};

export type PermissionInput = {
  name: string;
  methods: string[];
  description?: string | null;
  module?: string | null;
  sortOrder?: number;
};

const toPermission = (row: Tables<"permissions">): Permission => ({
  id: row.name,
  name: row.name,
  methods: row.methods,
  description: row.description,
  module: row.module,
  sortOrder: row.sort_order,
  createdAt: row.created_at,
});

const toColumns = (input: PermissionInput) => ({
  name: input.name,
  methods: input.methods ?? [],
  description: input.description || null,
  module: input.module?.trim() || null,
  sort_order: input.sortOrder ?? 0,
});

export const listPermissions = async (client: Client): Promise<Permission[]> =>
  unwrap(
    await client
      .from("permissions")
      .select("*")
      .order("sort_order")
      .order("module", { nullsFirst: false })
      .order("name")
  ).map(toPermission);

export const createPermission = async (client: Client, input: PermissionInput): Promise<Permission> =>
  toPermission(unwrap(await client.from("permissions").insert(toColumns(input)).select().single()));

export const updatePermission = async (
  client: Client,
  id: string,
  input: PermissionInput
): Promise<Permission> =>
  toPermission(
    unwrap(await client.from("permissions").update(toColumns(input)).eq("name", id).select().single())
  );

export const deletePermission = async (client: Client, id: string): Promise<void> => {
  const { error } = await client.from("permissions").delete().eq("name", id);
  if (error) throw error;
};
