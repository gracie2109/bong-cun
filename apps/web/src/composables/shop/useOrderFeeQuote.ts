import { computed, ref, type Ref } from "vue";
import { useShopSettings } from "@/queries/shop";
import { quoteShippingFee, ShippingQuoteError } from "@/services/shipment.service";
import type { AdminOrder } from "@/types/shopOrderAdmin";
import { clampQuote } from "@/utils/shop/shipping";

/** "Tính lại phí GHN" in the confirm dialog: asks GHN again with the order's real weight. */
export const useOrderFeeQuote = (order: Ref<AdminOrder | null>, onQuoted: (fee: number) => void) => {
  const settings = useShopSettings();
  const loading = ref(false);
  const failed = ref<"unavailable" | "too_heavy" | null>(null);

  const ready = computed(() => {
    const from = settings.data.value;
    const to = order.value;
    return !!(from?.ghnFromDistrictId && from.ghnFromWardCode && to?.ghnDistrictId && to.ghnWardCode);
  });

  const run = async () => {
    const from = settings.data.value;
    const to = order.value;
    if (!ready.value || !from || !to) return;
    loading.value = true;
    failed.value = null;
    try {
      const fee = await quoteShippingFee({
        fromDistrictId: from.ghnFromDistrictId as number,
        fromWardCode: from.ghnFromWardCode as string,
        toDistrictId: to.ghnDistrictId as number,
        toWardCode: to.ghnWardCode as string,
        weightG: to.weightG,
        insuranceValue: to.subtotal,
      });
      onQuoted(clampQuote(fee));
    } catch (error) {
      failed.value = error instanceof ShippingQuoteError ? error.reason : "unavailable";
    } finally {
      loading.value = false;
    }
  };

  return { ready, loading, failed, run };
};
