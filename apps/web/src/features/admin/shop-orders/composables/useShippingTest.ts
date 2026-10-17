import { computed, ref, type Ref } from "vue";
import { quoteLeadtime, quoteShippingFee, ShippingQuoteError } from "@/services/shipment.service";
import type { GhnLocation } from "@bongcun/core/shop";
import { formatPrice } from "@/lib/utils";

/** A fixed address to price against (Ha Dong, Ha Noi): it only proves GHN answers for this warehouse. */
const SAMPLE_TO = { toDistrictId: 1820, toWardCode: "030712" } as const;
const SAMPLE_WEIGHT_G = 1000;

type TestState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "ok"; fee: string; leadtime: string | null }
  | { status: "error"; reason: "unavailable" | "too_heavy" };

/** The "Thử tính phí" button of the shop settings: one sample quote from the warehouse in the form. */
export const useShippingTest = (from: Ref<GhnLocation>) => {
  const state = ref<TestState>({ status: "idle" });
  const ready = computed(() => Boolean(from.value.districtId && from.value.wardCode));

  const run = async () => {
    const { districtId, wardCode } = from.value;
    if (!districtId || !wardCode) return;
    state.value = { status: "loading" };
    const places = { fromDistrictId: districtId, fromWardCode: wardCode, ...SAMPLE_TO, weightG: SAMPLE_WEIGHT_G };
    try {
      const fee = await quoteShippingFee({ ...places, insuranceValue: 0 });
      const leadtime = await quoteLeadtime(places).catch(() => null);
      state.value = {
        status: "ok",
        fee: formatPrice(fee) ?? "",
        leadtime: leadtime ? leadtime.toLocaleDateString("vi-VN") : null,
      };
    } catch (error) {
      state.value = { status: "error", reason: error instanceof ShippingQuoteError ? error.reason : "unavailable" };
    }
  };

  return { state, ready, run };
};
