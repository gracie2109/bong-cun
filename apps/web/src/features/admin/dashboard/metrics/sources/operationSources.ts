import { computed } from "vue";
import { useBoardingBoard } from "@/features/admin/boarding";
import { useStockAlertCounts } from "@/features/admin/inventory";
import { useMedicalQueue, useMedicalReminders } from "@/features/admin/medical";
import { useDayBoard } from "@/features/admin/schedule";
import { useShopOrderBadge } from "@/features/admin/shop-orders";
import { countTickets } from "../../widgets/spa/spaStats";
import { petCounts } from "../../widgets/boarding/boardingStats";
import type { SourceContext, SourceResult } from "./context";

const number = (value: number | undefined) => (value === undefined ? null : ({ kind: "number", value } as const));

/** The branch for a source, only while that source serves the metric (an idle source leaves its query off). */
const branchFor = (ctx: SourceContext, source: Parameters<SourceContext["isActive"]>[0]) =>
  computed(() => (ctx.isActive(source) ? ctx.branchId.value : undefined));

export const useStockSource = (ctx: SourceContext): SourceResult => {
  const days = computed(() => Number(ctx.params.value.days) || 60);
  const query = useStockAlertCounts(branchFor(ctx, "stock"), days);
  const value = computed(() => {
    const counts = query.data.value as Record<string, number> | undefined;
    return number(counts?.[ctx.def.pick]);
  });
  return { query, value };
};

export const useOrdersSource = (ctx: SourceContext): SourceResult => {
  const query = useShopOrderBadge(computed(() => ctx.isActive("orders") && !!ctx.branchId.value));
  return { query, value: computed(() => number(query.data.value)) };
};

export const useSpaSource = (ctx: SourceContext): SourceResult => {
  const query = useDayBoard(branchFor(ctx, "spa"), ctx.today);
  const value = computed(() => {
    const board = query.data.value;
    if (!board) return null;
    const counts = countTickets(board.tickets);
    const status = ctx.params.value.status;
    if (status === "waiting") return number(counts.waiting);
    if (status === "inProgress") return number(counts.inProgress);
    if (status === "done") return number(counts.done);
    return number(counts.waiting + counts.inProgress + counts.done);
  });
  return { query, value };
};

export const useBoardingSource = (ctx: SourceContext): SourceResult => {
  const query = useBoardingBoard(branchFor(ctx, "boarding"), ctx.today);
  const value = computed(() => {
    const board = query.data.value;
    if (!board) return null;
    const counts = ctx.params.value.unit === "pets" ? petCounts(board) : board.counts;
    return number(counts[ctx.params.value.count as "occupied" | "arriving" | "departing" | "overdue"]);
  });
  return { query, value };
};

const ONE_ROW = { pageIndex: 1, pageSize: 1 };
const OVERDUE = { scope: "overdue" } as const;

export const useMedicalSource = (ctx: SourceContext): SourceResult => {
  const branch = branchFor(ctx, "medical");
  const queue = useMedicalQueue(computed(() => (ctx.def.pick === "queue" ? branch.value : undefined)), ctx.today);
  const reminders = useMedicalReminders(computed(() => (ctx.def.pick === "vaccineOverdue" ? branch.value : undefined)), ONE_ROW, OVERDUE);
  const query = ctx.def.pick === "queue" ? queue : reminders;
  const value = computed(() => {
    if (ctx.def.pick === "vaccineOverdue") return number(reminders.data.value?.total);
    const counts = queue.data.value?.counts;
    if (!counts) return null;
    const status = ctx.params.value.status;
    return number(status === "inProgress" ? counts.inProgress : status === "done" ? counts.done : counts.waiting);
  });
  return { query, value };
};
