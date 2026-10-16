import { computed, reactive, ref, type Ref } from "vue";
import { toast } from "vue-sonner";
import i18n from "@/i18n";
import { useOrderStep, useShopOrderDetail } from "@/queries/shopOrdersAdmin";
import { stepErrorHint } from "@bongcun/supabase/shop";
import type { OrderStepCall } from "@bongcun/supabase/shop";
import { codAmount, orderActions, type OrderAction } from "@bongcun/core/shop";

/** Steps that ask for something first; the others (pack) only ask "are you sure". */
type Dialog = OrderAction | null;

/** The open order of the staff screen: its detail, which dialog is open and the steps. */
export const useOrderSheet = (id: Ref<string | undefined>) => {
  const query = useShopOrderDetail(id);
  const stepMutation = useOrderStep();

  const order = computed(() => query.data.value ?? null);
  const actions = computed(() => (order.value ? orderActions(order.value) : []));
  const dialog = ref<Dialog>(null);

  const explain = (error: unknown) => {
    const hint = stepErrorHint(error);
    const t = i18n.global.t;
    const detail = (error as { details?: string } | null)?.details ?? "";
    toast.error(hint ? t(`shop.admin.errors.${hint}`, { detail }) : t("shop.admin.errors.generic"));
  };

  /** Runs one step; on success the dialog closes, on failure it stays so the input is kept. */
  const run = async (call: OrderStepCall): Promise<boolean> => {
    try {
      await stepMutation.mutateAsync(call);
      dialog.value = null;
      toast.success(i18n.global.t(`shop.admin.done.${call.step}`));
      return true;
    } catch (error) {
      explain(error);
      // The order may have been moved by someone else; read it again.
      void query.refetch();
      return false;
    }
  };

  const form = reactive({ fee: "", tracking: "", reason: "" });
  const open = (action: OrderAction) => {
    const current = order.value;
    if (!current) return;
    form.fee = String(current.shippingFee ?? current.shippingFeeQuote);
    form.tracking = "";
    form.reason = "";
    dialog.value = action;
  };

  return {
    order,
    loading: query.isPending,
    actions,
    dialog,
    form,
    busy: stepMutation.isPending,
    open,
    close: () => (dialog.value = null),
    run,
    cod: computed(() => (order.value ? codAmount(order.value) : 0)),
  };
};
