import { computed } from "vue";
import { useHead } from "#imports";
import { useRoute } from "vue-router";
import { useSellableGroup } from "@/queries/products";
import { useRelatedGroups, useVariantAvailability } from "@/queries/shopCatalog";
import { useVariantChoice } from "@/composables/useVariantChoice";
import { useAddToCart } from "./useAddToCart";

/** Variants with at most this many left show "only N left". */
const LOW_STOCK = 10;

export type ProductStatus = "loading" | "error" | "ready" | "discontinued";

/** The product page: the group, which variant is picked, its stock, adding to cart, related groups. */
export const useProductPage = () => {
  const route = useRoute();
  const id = computed(() => String(route.params.id ?? ""));

  const groupQuery = useSellableGroup(id);
  const group = computed(() => groupQuery.data.value ?? null);
  const variantIds = computed(() => (group.value?.variants ?? []).map((variant) => variant.id));

  const availability = useVariantAvailability(variantIds);
  const canSell = (variant: { id: string; trackStock: boolean }) =>
    !variant.trackStock || (availability.data.value?.[variant.id] ?? 1) > 0;

  const choice = useVariantChoice(group, canSell);
  const addToCart = useAddToCart(choice.variant);
  const related = useRelatedGroups(id);

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
    const left = availability.data.value?.[picked.id];
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
