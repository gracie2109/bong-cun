import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import { useCancelShopOrder, useMyShopOrder } from "@/queries/shopOrders";
import { orderErrorHint } from "@bongcun/supabase/shop";
import { canCancelOrder, feeWentUp, orderSteps } from "@bongcun/core/shop";

/** State and actions of /orders/:code: the order, its progress line and the customer cancel. */
export const useOrderPage = () => {
  const route = useRoute();
  const code = computed(() => String(route.params.code ?? ""));
  const query = useMyShopOrder(code);
  const cancelMutation = useCancelShopOrder();

  const order = computed(() => query.data.value ?? null);
  /** The order does not exist, or belongs to someone else. */
  const notFound = computed(() => query.isError.value && orderErrorHint(query.error.value) === "order_not_found");
  const steps = computed(() => (order.value ? orderSteps(order.value.deliveryMethod, order.value.status, order.value.events) : []));
  const cancellable = computed(() => !!order.value && canCancelOrder(order.value.status));

  const cancelOpen = ref(false);
  const cancelReason = ref("");
  const openCancel = () => {
    cancelReason.value = "";
    cancelOpen.value = true;
  };
  const confirmCancel = async () => {
    try {
      await cancelMutation.mutateAsync({ code: code.value, reason: cancelReason.value });
      cancelOpen.value = false;
    } catch {
      // the mutation showed the failure toast; the order is read again so the page shows its real state
      cancelOpen.value = false;
      void query.refetch();
    }
  };

  return {
    order,
    loading: query.isLoading,
    failed: computed(() => query.isError.value && !notFound.value),
    notFound,
    retry: () => query.refetch(),
    steps,
    cancellable,
    feeWentUp: computed(() => !!order.value && feeWentUp(order.value)),
    cancelOpen,
    cancelReason,
    cancelling: cancelMutation.isPending,
    openCancel,
    confirmCancel,
  };
};
