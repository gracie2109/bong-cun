// Where each file of src/queries and src/composables goes in step 7 of
// docs/ke-hoach-don-monorepo-con-lai.md. `scripts/feature-owners.mjs` prints the proposal from the
// import graph; this table holds the final calls where the graph does not give one answer.
// Key: path under src without extension. Value: the module folder in src/features, or "stay".
export const STAY = "stay";

/** Generic helpers many modules use. They have no business owner and stay in src/composables. */
const generic = [
  "composables/listFilters",
  "composables/useListFilters",
  "composables/usePagedList",
  "composables/usePagedRows",
  "composables/usePagedSearch",
  "composables/usePermission",
  "composables/usePolling",
  "composables/useCurrentBranch",
  "composables/useTableExport",
  "composables/useTableImport",
  "composables/useToastImage",
  "composables/useInfiniteOptions",
  "composables/useValidation",
  "composables/layout/useHeaderSearch",
  "composables/shop/useServerPrefetch",
];

/** Files whose users are in more than one module, or in admin and shop, or that no screen uses. */
const decided = {
  // used by admin and shop: shared (may not import admin or shop)
  "queries/branches": "shared/branches",
  "queries/products": "shared/products",
  "queries/productCategories": "shared/products",
  "composables/useVariantChoice": "shared/products",
  "queries/shop": "shared/shop",
  "queries/ghnLocations": "shared/shop",
  "composables/shop/useGhnLocationPicker": "shared/shop",
  // several admin modules: the module that owns the business rule
  "queries/boarding/action": "admin/boarding",
  "queries/boarding/calendar": "admin/boarding",
  "queries/boarding/care": "admin/boarding",
  "queries/boarding/failure": "admin/boarding",
  "queries/boarding/index": "admin/boarding",
  "queries/boarding/kennels": "admin/boarding",
  "queries/boarding/stays": "admin/boarding",
  "queries/branchPrices": "admin/products",
  "queries/customers": "admin/pets",
  "queries/dataImports": "admin/inventory",
  "queries/inventory": "admin/inventory",
  "queries/medical": "admin/medical",
  "queries/medicalVisits": "admin/medical",
  "queries/vaccinations": "admin/medical",
  "queries/petServices": "admin/pets",
  "queries/species": "admin/pets",
  "queries/pos": "admin/pos",
  "queries/spa": "admin/schedule",
  "queries/reports": "admin/reports",
  // several shop modules
  "queries/account": "shop/account",
  "queries/shopAddresses": "shop/account",
  "queries/shopCatalog": "shop/catalog",
  "queries/shopOrders": "shop/orders",
  "queries/spaCatalog": "shop/spa",
  "composables/shop/useAddToCart": "shop/cart",
  "composables/shop/useAddressForm": "shop/account",
  "composables/shop/useCartView": "shop/cart",
  "composables/spa/useDurationLabel": "shop/spa",
  "composables/spa/useSpaCatalog": "shop/spa",
  // no screen imports it today: left where it is
  "queries/bookings": STAY,
};

export const decisions = { ...Object.fromEntries(generic.map((file) => [file, STAY])), ...decided };
