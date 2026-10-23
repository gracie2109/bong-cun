import { computed, type ComputedRef, type Ref } from "vue";
import { useBoardingBoard } from "@/features/admin/boarding";
import { useStockAlertCounts } from "@/features/admin/inventory";
import { useMedicalReminders } from "@/features/admin/medical";
import { useShopOrderBadge } from "@/features/admin/shop-orders";
import { useBranchIfAllowed, useWidgetAccess } from "../../kit/widgetScope";
import { resolveWidgetState } from "../../kit/widgetState";
import { useToday } from "../../useToday";
import { allClear, ROUTES, sortRows, type ActionRow, type ActionRowKey } from "./actionItems";

const EXPIRY_DAYS = 60;
const ONE_ROW = { pageIndex: 1, pageSize: 1 };
const OVERDUE = { scope: "overdue" } as const;

type Source = { isError: Ref<boolean>; isPending: Ref<boolean>; isPlaceholderData?: Ref<boolean> };

const rowOf = (key: ActionRowKey, source: Source, count: number | undefined, on: boolean): ActionRow | null =>
  on
    ? {
        key,
        failed: source.isError.value,
        count: source.isError.value || source.isPending.value || source.isPlaceholderData?.value ? null : (count ?? 0),
        to: { name: ROUTES[key] },
      }
    : null;

/** Everything that needs doing at the branch, one independent source per row (a refused source hides only its own rows). */
export const useActionItems = () => {
  const { allowed, needsBranch } = useWidgetAccess(
    ["shop_orders", "inventory", "medical", "boarding"],
    ["branch"]
  );
  const today = useToday();
  const ordersBranch = useBranchIfAllowed("shop_orders");
  const stockBranch = useBranchIfAllowed("inventory");
  const medicalBranch = useBranchIfAllowed("medical");
  const boardingBranch = useBranchIfAllowed("boarding");

  const orders = useShopOrderBadge(computed(() => !!ordersBranch.value));
  const stock = useStockAlertCounts(stockBranch, EXPIRY_DAYS);
  const vaccines = useMedicalReminders(medicalBranch, ONE_ROW, OVERDUE);
  const boarding = useBoardingBoard(boardingBranch, today);

  const rows: ComputedRef<ActionRow[]> = computed(() =>
    sortRows(
      [
        rowOf("pendingOrders", orders, orders.data.value, !!ordersBranch.value),
        rowOf("stockLow", stock, stock.data.value?.low, !!stockBranch.value),
        rowOf("stockExpiring", stock, stock.data.value?.expiring, !!stockBranch.value),
        rowOf("stockExpired", stock, stock.data.value?.expired, !!stockBranch.value),
        rowOf("vaccineOverdue", vaccines, vaccines.data.value?.total, !!medicalBranch.value),
        rowOf("boardingOverdue", boarding, boarding.data.value?.counts.overdue, !!boardingBranch.value),
      ].filter((row): row is ActionRow => row !== null)
    )
  );

  const sources = [orders, stock, vaccines, boarding];
  const state = computed(() => {
    if (!allowed.value || needsBranch.value) {
      return resolveWidgetState({ allowed: allowed.value, needsBranch: needsBranch.value, query: { isPending: false, isError: false }, isEmpty: false });
    }
    const active = rows.value;
    const pending = active.some((row) => row.count === null && !row.failed);
    const everyFailed = active.length > 0 && active.every((row) => row.failed);
    return resolveWidgetState({
      allowed: true,
      query: { isPending: pending && active.every((row) => row.count === null), isError: everyFailed },
      isEmpty: allClear(active),
    });
  });

  const refetch = () => sources.forEach((source) => void source.refetch());
  return { state, rows, refetch };
};
