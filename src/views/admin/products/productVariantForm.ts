
/** An attribute being edited: `draft` is the value still being typed. */
export type AttributeForm = { uid: number; name: string; values: string[]; draft: string };

export type VariantRow = {
  key: string;
  id?: string;
  options: string[];
  sku: string;
  barcode: string;
  unit: string;
  price: string;
  trackStock: boolean;
  isActive: boolean;
  imageUrl: string;
};

type Translate = (key: string) => string;

let nextUid = 0;

export const newAttribute = (init: Partial<Omit<AttributeForm, "uid">> = {}): AttributeForm => ({
  uid: nextUid++,
  name: "",
  values: [],
  draft: "",
  ...init,
});

export const same = (a: string, b: string): boolean => a.trim().toLowerCase() === b.trim().toLowerCase();

/** Identifies a combination by attribute name and value, so reordering attributes keeps the row. */
export const comboKey = (names: string[], options: string[]): string =>
  names
    .map((name, index) => `${name.trim().toLowerCase()}=${(options[index] ?? "").trim().toLowerCase()}`)
    .sort()
    .join("|");

/** Turns the typed draft (comma separated) into values, skipping ones already picked. */
export const commitDraft = (attribute: AttributeForm) => {
  for (const part of attribute.draft.split(",")) {
    const value = part.trim();
    if (value && !attribute.values.some((existing) => same(existing, value))) attribute.values.push(value);
  }
  attribute.draft = "";
};

export const attributeError = (attributes: readonly AttributeForm[], attribute: AttributeForm, t: Translate): string => {
  if (!attribute.name.trim()) return t("petCare.common.required");
  if (attributes.filter((item) => same(item.name, attribute.name)).length > 1) return t("products.attributes.duplicate");
  if (!attribute.values.length) return t("products.attributes.needValue");
  return "";
};
