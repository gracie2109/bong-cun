import { useQuery } from "@tanstack/vue-query";
import { computed } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { shopKeys } from "@/queries/keys";
import { fetchCartLines } from "@/repositories/shop";
import { useCart } from "@/stores";
import type { CartLineView } from "@/types/shop";
import { cartSubtotal, cartWeightG, hasCartIssue, hasInStoreOnly, lineKey } from "@/utils/shop/cart";

/**
 * The cart with live data. Only the set of (product, unit) pairs decides when the database is
 * asked again, so changing a quantity updates totals instantly without a request. Quantities
 * always come from the local cart.
 */
export const useCartView = () => {
  const cart = useCart();

  const keys = computed(() => cart.lines.map(lineKey).sort());
  const query = useQuery({
    queryKey: computed(() => shopKeys.cart(keys.value)),
    // The query function runs for the current lines; quantities are applied below.
    queryFn: () => fetchCartLines(supabaseClient(), cart.lines),
    enabled: computed(() => cart.lines.length > 0),
    staleTime: 30_000,
    refetchOnWindowFocus: true,
  });

  const lines = computed<CartLineView[]>(() => {
    const live = new Map((query.data.value ?? []).map((line) => [lineKey(line), line]));
    return cart.lines.flatMap((line) => {
      const view = live.get(lineKey(line));
      return view ? [{ ...view, qty: line.qty }] : [];
    });
  });

  return {
    lines,
    /** First load of a cart that has lines, before anything can be shown. */
    loading: computed(() => cart.lines.length > 0 && query.isLoading.value),
    failed: computed(() => query.isError.value),
    subtotal: computed(() => cartSubtotal(lines.value)),
    weightG: computed(() => cartWeightG(lines.value)),
    hasIssue: computed(() => hasCartIssue(lines.value)),
    inStoreOnly: computed(() => hasInStoreOnly(lines.value)),
    refresh: () => query.refetch(),
  };
};
