import { computed, type Ref } from "vue";
import { useI18n } from "vue-i18n";
import { useAllPetServices } from "@/queries/petServices";
import { useBranchPrices } from "@/queries/branchPrices";
import { useSellableStock } from "@/queries/inventory";
import { useSellableCombos } from "@/queries/pos";
import { useSellableProducts } from "@/queries/products";
import type { LineType } from "@/repositories/pos";
import { fold } from "@/views/admin/settings/rbac";
import { priceAtBranch } from "./branchPricing";
import { groupProductItems, type CatalogItem } from "./catalog";

/** The tiles of the POS catalog for the open tab, with their stock at the branch. */
export const useCatalogItems = (
  kind: Ref<LineType>,
  search: Ref<string>,
  debouncedSearch: Ref<string>,
  branchId: () => string | undefined,
  categoryIds: Ref<readonly string[]>
) => {
  const { t } = useI18n();

  const productsQuery = useSellableProducts(debouncedSearch, categoryIds);
  const servicesQuery = useAllPetServices();
  const combosQuery = useSellableCombos();

  // Branch prices come in a second call, so tiles first show the general price.
  const productIds = computed(() => (productsQuery.data.value ?? []).map((product) => product.id));
  const branchPricesQuery = useBranchPrices(computed(branchId), productIds);
  const pricedProducts = computed(() =>
    (productsQuery.data.value ?? []).map((product) => priceAtBranch(product, branchPricesQuery.data.value))
  );

  const productItems = computed(() => groupProductItems(pricedProducts.value, (n) => t("pos.variant.count", { n })));

  const matches = (name: string) => fold(name).includes(fold(search.value));

  const items = computed<CatalogItem[]>(() => {
    if (kind.value === "product") return productItems.value;
    if (kind.value === "service") {
      return (servicesQuery.data.value ?? [])
        .filter((service) => matches(service.name))
        .map((service) => ({
          type: "service",
          id: service.id,
          name: service.name,
          price: service.type === "by_weight" ? null : service.generalPrice ?? 0,
          unit: null,
          hint: service.species.map((item) => item.name).join(", "),
        }));
    }
    return (combosQuery.data.value ?? [])
      .filter((combo) => matches(combo.name))
      .map((combo) => ({ type: "combo", id: combo.id, name: combo.name, price: combo.price, unit: null, hint: "" }));
  });

  // Unexpired stock at this branch for the product tiles; products that do not track stock have none.
  const stockQuery = useSellableStock(computed(branchId), productIds);

  /** Units in stock for a product tile, or undefined when stock is not tracked or not known yet. */
  const stockOf = (item: CatalogItem): number | undefined => {
    if (item.type !== "product") return undefined;
    if (!item.groupId) return stockQuery.data.value?.[item.id];
    // A group tile counts its variants' stock only when every one of them tracks stock.
    const variants = (productsQuery.data.value ?? []).filter((product) => product.groupId === item.groupId);
    if (!variants.every((variant) => variant.trackStock)) return undefined;
    const counts = variants.map((variant) => stockQuery.data.value?.[variant.id]);
    if (!counts.every((count): count is number => count !== undefined)) return undefined;
    return counts.reduce((sum, count) => sum + count, 0);
  };

  const loading = computed(() => {
    if (kind.value === "product") return productsQuery.isPending.value;
    if (kind.value === "service") return servicesQuery.isPending.value;
    return combosQuery.isPending.value;
  });

  return { items, loading, stockOf };
};
