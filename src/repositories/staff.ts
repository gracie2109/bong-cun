// Staff accounts and the role each one holds at each branch (staff_branches).
// A staff account is any user whose account type (users.role) is not "customer".
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;

const CUSTOMER_ROLE = "customer";

export type StaffAssignment = { branchId: string; role: string };

export type StaffMember = {
  id: string;
  name: string;
  email: string | null;
  photoUrl: string | null;
  accountRole: string;
  assignments: StaffAssignment[];
};

export const listStaff = async (client: Client): Promise<StaffMember[]> => {
  const rows = unwrap(
    await client
      .from("users")
      .select("id, full_name, display_name, email, photo_url, role, staff_branches(branch_id, role)")
      .neq("role", CUSTOMER_ROLE)
      .order("full_name")
  );
  return rows.map((row) => ({
    id: row.id,
    name: row.full_name || row.display_name || row.email || row.id,
    email: row.email,
    photoUrl: row.photo_url,
    accountRole: row.role,
    assignments: row.staff_branches.map((item) => ({ branchId: item.branch_id, role: item.role })),
  }));
};

/** Replaces every branch role of one staff member. */
export const saveStaffAssignments = async (
  client: Client,
  userId: string,
  assignments: StaffAssignment[]
): Promise<void> => {
  const { error } = await client.rpc("save_staff_branches", {
    p_user: userId,
    p: assignments.map((item) => ({ branch_id: item.branchId, role: item.role })),
  });
  if (error) throw error;
};
