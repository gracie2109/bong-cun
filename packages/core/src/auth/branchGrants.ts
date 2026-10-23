import type { AdminGrants } from "./access";

/** Branch id -> permission code -> methods the user holds at that branch. */
export type BranchGrants = Record<string, Record<string, readonly string[]>>;

const holds = (methods: readonly string[] | undefined, method: string) =>
  (methods ?? []).some((item) => item === method || item === "ALL");

/**
 * Whether the account may use a permission at one branch. Admin accounts without branch roles
 * ("all") may everywhere, matching is_admin() in the database. `canUse` answers for "any branch"
 * and must not decide what to show for the branch being viewed.
 */
export const canUseAt = (
  grants: AdminGrants,
  byBranch: BranchGrants,
  permission: string,
  branchId: string | null | undefined,
  method = "VIEW"
): boolean => grants === "all" || (!!branchId && holds(byBranch[branchId]?.[permission], method));

/** The branch ids, out of `branchIds`, where the account holds the permission. */
export const branchesWithPermission = (
  grants: AdminGrants,
  byBranch: BranchGrants,
  branchIds: readonly string[],
  permission: string,
  method = "VIEW"
): string[] => branchIds.filter((id) => canUseAt(grants, byBranch, permission, id, method));

/** Branches where the account holds at least one permission (the ones worth offering in a picker). */
export const branchesWithAnyRole = (
  grants: AdminGrants,
  byBranch: BranchGrants,
  branchIds: readonly string[]
): string[] =>
  grants === "all" ? [...branchIds] : branchIds.filter((id) => Object.keys(byBranch[id] ?? {}).length > 0);
