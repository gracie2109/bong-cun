import { computed, inject, provide, type ComputedRef, type InjectionKey } from "vue";
import { useAuthStore } from "@/stores";
import { widgetAccess } from "../dashboardRules";
import type { DashboardScope, ScopeKind } from "./types";

const SCOPE_KEY: InjectionKey<ComputedRef<DashboardScope>> = Symbol("dashboardScope");

export const provideWidgetScope = (scope: ComputedRef<DashboardScope>) => provide(SCOPE_KEY, scope);

export const useWidgetScope = (): ComputedRef<DashboardScope> => {
  const scope = inject(SCOPE_KEY);
  if (!scope) throw new Error("A dashboard widget must be rendered inside a dashboard.");
  return scope;
};

/**
 * What the widget may read for the scope in force: `branchId` is set only when it may ask for one
 * branch, `reportBranchId` is null for "all branches" (the database adds up the allowed ones).
 */
export const useWidgetAccess = (
  permissions: readonly string[],
  scopes: readonly ScopeKind[],
  scope: ComputedRef<DashboardScope> = useWidgetScope()
) => {
  const auth = useAuthStore();
  const access = computed(() => widgetAccess({ permissions, scopes }, scope.value, auth.canAt));
  const allowed = computed(() => access.value === "allowed");
  const branchId = computed(() =>
    allowed.value && scope.value.kind === "branch" ? scope.value.branchId : undefined
  );
  const isAll = computed(() => allowed.value && scope.value.kind === "all");
  return { access, scope, allowed, needsBranch: computed(() => access.value === "needsBranch"), branchId, isAll };
};

/** The branch to ask about for one source of a combined widget; undefined while the account lacks the permission there. */
export const useBranchIfAllowed = (permission: string, scope: ComputedRef<DashboardScope> = useWidgetScope()) => {
  const auth = useAuthStore();
  return computed(() => {
    const { kind, branchId } = scope.value;
    return kind === "branch" && branchId && auth.canAt(permission, branchId) ? branchId : undefined;
  });
};
