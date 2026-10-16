import { refDebounced } from "@vueuse/core";
import { useQuery } from "@tanstack/vue-query";
import { computed, type Ref } from "vue";
import { quoteLeadtime, quoteShippingFee, type ShippingPlaces } from "@/services/shipment.service";
import type { Address, ShopPublicSettings } from "@bongcun/core/shop";
import {
  canDeliver,
  isFreeShip,
  orderWeightG,
  resolveShippingFee,
  type FeeSource,
} from "@/utils/shop/shipping";

const SETTLE_MS = 500;
const FIVE_MINUTES = 5 * 60 * 1000;

type Options = {
  settings: Ref<ShopPublicSettings | undefined>;
  /** The delivery address; null while none is chosen (or when picking up in store). */
  address: Ref<Address | null>;
  /** Grams of the goods in the cart, without packaging. */
  goodsG: Ref<number>;
  subtotal: Ref<number>;
  /** Off for pickup: nothing is asked of GHN. */
  enabled: Ref<boolean>;
};

/**
 * The estimated shipping fee and delivery date for the cart. GHN is asked once the inputs have
 * settled; when it cannot answer, or the warehouse is not set up, the flat fee is used and the fee
 * is marked as an estimate. Free shipping above the threshold skips GHN altogether.
 */
export const useShippingQuote = (options: Options) => {
  const goodsG = refDebounced(options.goodsG, SETTLE_MS);
  const subtotal = refDebounced(options.subtotal, SETTLE_MS);
  const parcelG = computed(() => orderWeightG(goodsG.value));

  const tooHeavy = computed(() => !canDeliver(parcelG.value));
  const free = computed(() => isFreeShip(subtotal.value, options.settings.value?.freeShipFrom ?? null));

  /** The two places, when the warehouse and the address are both known. */
  const places = computed<ShippingPlaces | null>(() => {
    const settings = options.settings.value;
    const address = options.address.value;
    if (!options.enabled.value || !settings || !address) return null;
    if (!settings.ghnFromDistrictId || !settings.ghnFromWardCode) return null;
    return {
      fromDistrictId: settings.ghnFromDistrictId,
      fromWardCode: settings.ghnFromWardCode,
      toDistrictId: address.ghnDistrictId,
      toWardCode: address.ghnWardCode,
      weightG: parcelG.value,
    };
  });

  const canAsk = computed(() => places.value !== null && !tooHeavy.value);

  const fee = useQuery({
    queryKey: computed(() => ["ghn-fee", places.value, subtotal.value] as const),
    queryFn: () => quoteShippingFee({ ...(places.value as ShippingPlaces), insuranceValue: subtotal.value }),
    enabled: computed(() => canAsk.value && !free.value),
    retry: false,
    staleTime: FIVE_MINUTES,
  });

  const leadtime = useQuery({
    queryKey: computed(() => ["ghn-leadtime", places.value] as const),
    queryFn: () => quoteLeadtime(places.value as ShippingPlaces),
    enabled: canAsk,
    retry: false,
    staleTime: FIVE_MINUTES,
  });

  const quote = computed(() =>
    resolveShippingFee({
      subtotal: subtotal.value,
      freeShipFrom: options.settings.value?.freeShipFrom ?? null,
      flatFee: options.settings.value?.flatShippingFee ?? 0,
      ghnFee: fee.data.value ?? null,
    })
  );

  return {
    fee: computed(() => quote.value.fee),
    source: computed<FeeSource>(() => quote.value.source),
    /** "Phí dự kiến": GHN could not price it, so the flat fee stands in. */
    estimated: computed(() => quote.value.source === "flat"),
    /** GHN is being asked right now. */
    loading: computed(() => canAsk.value && !free.value && fee.isFetching.value),
    tooHeavy,
    /** Expected delivery time, or null when unknown (the line is then hidden). */
    leadtime: computed(() => (canAsk.value ? (leadtime.data.value ?? null) : null)),
  };
};
