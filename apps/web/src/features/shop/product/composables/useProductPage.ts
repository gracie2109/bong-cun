import { computed } from "vue";
import { useHead } from "#imports";
import { useRoute } from "vue-router";
import { usePublicGroup } from "@/features/shared/public-api";
import { useRelatedGroups } from "@/features/shop/catalog";
import { useVariantChoice } from "@/features/shared/products";
import { useServerPrefetch } from "@/composables/shop/useServerPrefetch";
import { useAddToCart } from "@/features/shop/cart";

/** Variants with at most this many left show "only N left". */
const LOW_STOCK = 10;

export type ProductStatus = "loading" | "error" | "ready" | "discontinued";

/** The product page: the group, which variant is picked, its stock, adding to cart, related groups. */
export const useProductPage = () => {
  const route = useRoute();
  const id = computed(() => String(route.params.id ?? ""));

  const groupQuery = usePublicGroup(id);
  const group = computed(() => groupQuery.data.value?.group ?? null);
  // How many of each variant can be bought now; it comes with the group.
  const availability = computed(() => groupQuery.data.value?.stock ?? {});
  const canSell = (variant: { id: string; trackStock: boolean }) =>
    !variant.trackStock || (availability.value[variant.id] ?? 1) > 0;

  const choice = useVariantChoice(group, canSell);
  const addToCart = useAddToCart(choice.variant);
  const related = useRelatedGroups(id);
  useServerPrefetch(groupQuery, related);

  const status = computed<ProductStatus>(() => {
    if (groupQuery.isPending.value) return "loading";
    if (groupQuery.isError.value) return "error";
    const loaded = group.value;
    return !loaded || !loaded.isActive || loaded.variants.length === 0 ? "discontinued" : "ready";
  });

  /** "in" / "out" / "low" with the count, for the picked variant. */
  const stock = computed(() => {
    const picked = choice.variant.value;
    if (!picked) return null;
    if (!picked.trackStock) return { kind: "in" as const, count: null };
    const left = availability.value[picked.id];
    if (left === undefined) return null;
    if (left <= 0) return { kind: "out" as const, count: 0 };
    return { kind: left <= LOW_STOCK ? ("low" as const) : ("in" as const), count: left };
  });
  const canAdd = computed(() => Boolean(choice.variant.value) && stock.value?.kind !== "out");

  useHead({ title: computed(() => group.value?.name ?? "") });

  return {
    group,
    status,
    choice,
    addToCart,
    stock,
    canAdd,
    related: computed(() => related.data.value ?? []),
    retry: () => void groupQuery.refetch(),
  };
};
