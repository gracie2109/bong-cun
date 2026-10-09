import { computed, reactive, ref, watch } from "vue";
import type { ProductGroup } from "@/repositories/products";
import { comboKey, newAttribute, type AttributeForm, type VariantRow } from "./productVariantForm";

const DEFAULT_UNIT = "cái";

/** The attributes of a product group and the variant rows made from every combination of their values. */
export const useProductVariants = () => {
  const attributes = ref<AttributeForm[]>([]);
  const rows = ref<VariantRow[]>([]);
  const bulk = reactive({ price: "", unit: "" });
  // Every variant row made while the sheet is open, by its values, so a value removed and typed
  // again gets its SKU and price back.
  let remembered = new Map<string, VariantRow>();

  const usableAttributes = computed(() => attributes.value.filter((item) => item.name.trim() && item.values.length));

  /** Every combination of the attribute values, in attribute order; one empty combination without attributes. */
  const combos = computed(() =>
    usableAttributes.value.reduce<string[][]>(
      (acc, attribute) => acc.flatMap((prefix) => attribute.values.map((value) => [...prefix, value])),
      [[]]
    )
  );

  const blankRow = (key: string, options: string[]): VariantRow => ({
    key,
    options,
    sku: "",
    barcode: "",
    unit: bulk.unit.trim() || DEFAULT_UNIT,
    price: bulk.price,
    trackStock: true,
    isActive: true,
    imageUrl: "",
  });

  /**
   * Rows for the current combinations, reusing what was typed for each one. When a product without
   * attributes gets its first ones, its existing SKU (with its stock and sales) becomes the first variant.
   */
  const buildRows = (names: string[], list: string[][]) => {
    const plain = remembered.get("");
    let plainFree = Boolean(plain?.id) && list.every((options) => options.length > 0);
    return list.map((options) => {
      const key = comboKey(names, options);
      let row = remembered.get(key);
      if (!row && plainFree && plain) {
        remembered.delete("");
        row = plain;
        row.key = key;
        plainFree = false;
      }
      row ??= blankRow(key, options);
      row.options = options;
      remembered.set(key, row);
      return row;
    });
  };

  watch(
    combos,
    (list) => {
      rows.value = buildRows(usableAttributes.value.map((item) => item.name), list);
    },
    { deep: true }
  );

  /** Loads the attributes and variants of `group`, or a blank product. */
  const fill = (group: ProductGroup | null) => {
    bulk.price = "";
    bulk.unit = "";
    remembered = new Map();
    const names = (group?.attributes ?? []).map((item) => item.name);
    for (const variant of group?.variants ?? []) {
      const key = comboKey(names, variant.options);
      remembered.set(key, {
        key,
        id: variant.id,
        options: variant.options,
        sku: variant.sku ?? "",
        barcode: variant.barcode ?? "",
        unit: variant.unit,
        price: String(variant.price),
        trackStock: variant.trackStock,
        isActive: variant.isActive,
        imageUrl: variant.imageUrl ?? "",
      });
    }
    attributes.value = (group?.attributes ?? []).map((item) =>
      newAttribute({ name: item.name, values: [...item.values] })
    );
    // The watcher only fires on a change; build the rows for this group now.
    rows.value = buildRows(names, combos.value);
  };

  return { attributes, rows, bulk, fill };
};
