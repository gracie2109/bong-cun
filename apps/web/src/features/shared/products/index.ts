// Public surface of shared/products: what other features may import. Everything else stays private.
export { useVariantChoice } from "./composables/useVariantChoice";
export { useDeleteProductBrand, useDeleteProductCategory, useMoveProductCategory, useProductBrandOptions, useProductBrands, useProductCategories, useProductCategoryOptions, useSaveProductBrand, useSaveProductCategory } from "./queries/productCategories";
export { useProductAttributes, useProductGroup, useProductGroups, useSaveProductGroup, useSellableGroup, useSellableProducts, useSellableProductsPaged, useSetProductGroupActive } from "./queries/products";
