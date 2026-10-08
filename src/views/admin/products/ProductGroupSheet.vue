<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-5xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ groupId ? $t("products.edit") : $t("products.add") }}</SheetTitle>
        <SheetDescription>{{ $t("products.subtitle") }}</SheetDescription>
      </SheetHeader>

      <div v-if="groupId && groupQuery.isPending.value" class="space-y-3 p-6">
        <Skeleton v-for="i in 4" :key="i" class="h-10 w-full" />
      </div>

      <form v-else id="product-group-form" class="flex-1 space-y-6 overflow-y-auto px-6 py-5" @submit.prevent="submit">
        <!-- General -->
        <section class="grid gap-4 md:grid-cols-[1fr_12rem]">
          <div class="space-y-4">
            <div class="space-y-2">
              <Label for="group-name">{{ $t("products.form.name") }}</Label>
              <Input id="group-name" v-model="form.name" />
              <p v-if="submitted && !form.name.trim()" class="text-sm text-red-600">{{ $t("petCare.common.required") }}</p>
            </div>
            <div class="space-y-2">
              <Label for="group-desc">{{ $t("products.form.desc") }}</Label>
              <Textarea id="group-desc" v-model="form.desc" rows="2" class="resize-none" />
            </div>
          </div>
          <div class="space-y-2">
            <Label for="group-image">{{ $t("products.form.image") }}</Label>
            <ProductThumb :src="form.imageUrl" class="aspect-square w-full" />
            <Input id="group-image" v-model="form.imageUrl" :placeholder="URL_HINT" />
          </div>
        </section>

        <!-- Attributes -->
        <section class="space-y-3 rounded-xl border p-4">
          <div class="flex flex-wrap items-start justify-between gap-2">
            <div>
              <h3 class="font-semibold">{{ $t("products.attributes.title") }}</h3>
              <p class="text-xs text-muted-foreground">{{ $t("products.attributes.hint") }}</p>
            </div>
            <Button type="button" variant="outline" size="sm" @click="addAttribute">
              <Plus class="mr-1 size-4" />
              {{ $t("products.attributes.add") }}
            </Button>
          </div>

          <div v-for="(attribute, index) in attributes" :key="attribute.uid" class="space-y-2 rounded-lg bg-muted/40 p-3">
            <div class="flex flex-wrap items-center gap-2">
              <Input
                v-model="attribute.name"
                class="w-48 bg-white"
                :placeholder="$t('products.attributes.name')"
                :list="`attribute-names-${attribute.uid}`"
              />
              <datalist :id="`attribute-names-${attribute.uid}`">
                <option v-for="known in knownAttributes" :key="known.id" :value="known.name" />
              </datalist>
              <div class="flex min-w-60 flex-1 flex-wrap items-center gap-1.5 rounded-md border bg-white px-2 py-1.5">
                <span
                  v-for="value in attribute.values"
                  :key="value"
                  class="inline-flex items-center gap-1 rounded-full bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary"
                >
                  {{ value }}
                  <button type="button" :aria-label="$t('petCare.common.delete')" @click="removeValue(attribute, value)">
                    <X class="size-3" />
                  </button>
                </span>
                <input
                  v-model="attribute.draft"
                  class="min-w-28 flex-1 bg-transparent text-sm outline-none"
                  :placeholder="$t('products.attributes.valuesPlaceholder')"
                  :list="`attribute-values-${attribute.uid}`"
                  @keydown="onValueKey($event, attribute)"
                  @blur="commitDraft(attribute)"
                />
                <datalist :id="`attribute-values-${attribute.uid}`">
                  <option v-for="value in suggestedValues(attribute)" :key="value" :value="value" />
                </datalist>
              </div>
              <div class="flex items-center">
                <Button type="button" variant="ghost" size="icon" class="size-8" :disabled="index === 0" :aria-label="$t('products.attributes.up')" @click="moveAttribute(index, -1)">
                  <ArrowUp class="size-4" />
                </Button>
                <Button type="button" variant="ghost" size="icon" class="size-8" :disabled="index === attributes.length - 1" :aria-label="$t('products.attributes.down')" @click="moveAttribute(index, 1)">
                  <ArrowDown class="size-4" />
                </Button>
                <Button type="button" variant="ghost" size="icon" class="size-8 text-red-600" :aria-label="$t('products.attributes.remove')" @click="removeAttribute(index)">
                  <Trash2 class="size-4" />
                </Button>
              </div>
            </div>
            <p v-if="submitted && attributeError(attribute)" class="text-sm text-red-600">{{ attributeError(attribute) }}</p>
          </div>
        </section>

        <!-- Variants -->
        <section class="space-y-3">
          <div class="flex flex-wrap items-end justify-between gap-3">
            <div>
              <h3 class="font-semibold">{{ $t("products.variants.title", { n: rows.length }) }}</h3>
              <p class="text-xs text-muted-foreground">{{ $t("products.variants.hint") }}</p>
            </div>
            <div class="flex flex-wrap items-center gap-2">
              <Input v-model="bulk.price" class="w-32" inputmode="numeric" :placeholder="$t('products.variants.bulkPrice')" />
              <Input v-model="bulk.unit" class="w-28" :placeholder="$t('products.variants.bulkUnit')" />
              <Button type="button" variant="outline" size="sm" @click="applyBulk">{{ $t("products.variants.bulk") }}</Button>
            </div>
          </div>

          <div class="table-scroll rounded-xl border">
            <table class="w-full text-sm">
              <thead>
                <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
                  <th class="px-3 py-2 font-semibold">{{ $t("products.variants.variant") }}</th>
                  <th class="px-3 py-2 font-semibold">{{ $t("products.form.sku") }}</th>
                  <th class="px-3 py-2 font-semibold">{{ $t("products.form.barcode") }}</th>
                  <th class="px-3 py-2 font-semibold">{{ $t("products.form.unit") }}</th>
                  <th class="px-3 py-2 text-right font-semibold">{{ $t("products.form.price") }}</th>
                  <th class="px-3 py-2 text-center font-semibold">{{ $t("products.variants.stock") }}</th>
                  <th class="px-3 py-2 text-center font-semibold">{{ $t("products.variants.sell") }}</th>
                  <th class="px-3 py-2 font-semibold">{{ $t("products.variants.image") }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in rows" :key="row.key" class="border-t align-top" :class="row.isActive ? '' : 'bg-muted/40'">
                  <td class="whitespace-nowrap px-3 py-2 font-medium">
                    {{ row.options.join(" / ") || $t("products.variants.default") }}
                    <span v-if="!row.id" class="ml-1 rounded-full bg-amber-50 px-1.5 py-0.5 text-[10px] font-semibold text-amber-700">
                      {{ $t("products.variants.new") }}
                    </span>
                  </td>
                  <td class="px-3 py-2"><Input v-model="row.sku" class="h-8 w-28" /></td>
                  <td class="px-3 py-2"><Input v-model="row.barcode" class="h-8 w-32" /></td>
                  <td class="px-3 py-2">
                    <Input v-model="row.unit" class="h-8 w-20" />
                    <p v-if="submitted && !row.unit.trim()" class="text-xs text-red-600">{{ $t("petCare.common.required") }}</p>
                  </td>
                  <td class="px-3 py-2">
                    <Input v-model="row.price" class="h-8 w-28 text-right" inputmode="numeric" />
                    <p class="mt-0.5 text-right text-[11px] text-muted-foreground">{{ money(parseAmount(row.price)) }}</p>
                  </td>
                  <td class="px-3 py-2 text-center"><Switch v-model:checked="row.trackStock" /></td>
                  <td class="px-3 py-2 text-center"><Switch v-model:checked="row.isActive" /></td>
                  <td class="px-3 py-2">
                    <div class="flex items-center gap-2">
                      <ProductThumb :src="row.imageUrl || form.imageUrl" class="size-8 shrink-0" />
                      <Input v-model="row.imageUrl" class="h-8 w-40" :placeholder="URL_HINT" />
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <p v-if="rows.length > MANY_VARIANTS" class="text-xs text-amber-700">
            {{ $t("products.variants.many", { n: rows.length }) }}
          </p>
        </section>
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button type="button" variant="outline" @click="emit('update:open', false)">{{ $t("petCare.common.cancel") }}</Button>
        <Button type="submit" form="product-group-form" :disabled="mutation.isPending.value || (Boolean(groupId) && groupQuery.isPending.value)">
          {{ $t("petCare.common.save") }}
        </Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, reactive, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { ArrowDown, ArrowUp, Plus, Trash2, X } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import { useProductAttributes, useProductGroup, useSaveProductGroup } from "@/queries/products";
import type { ProductGroup } from "@/repositories/products";
import { money, parseAmount } from "@/views/admin/pos/format";
import ProductThumb from "./ProductThumb.vue";

const DEFAULT_UNIT = "cái";
const MANY_VARIANTS = 100;
const URL_HINT = "https://...";

type AttributeForm = { uid: number; name: string; values: string[]; draft: string };
type VariantRow = {
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

const props = defineProps<{ open: boolean; groupId: string | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();
const { t } = useI18n();

const form = reactive({ name: "", desc: "", imageUrl: "", isActive: true });
const attributes = ref<AttributeForm[]>([]);
const rows = ref<VariantRow[]>([]);
const bulk = reactive({ price: "", unit: "" });
const submitted = ref(false);
let nextUid = 0;
// Every variant row made while the sheet is open, by its values, so a value removed and typed
// again gets its SKU and price back.
let remembered = new Map<string, VariantRow>();

const groupQuery = useProductGroup(computed(() => (props.open && props.groupId) || undefined));
const attributesQuery = useProductAttributes();
const knownAttributes = computed(() => attributesQuery.data.value ?? []);
const mutation = useSaveProductGroup();

const same = (a: string, b: string) => a.trim().toLowerCase() === b.trim().toLowerCase();

/** Identifies a combination by attribute name and value, so reordering attributes keeps the row. */
const comboKey = (names: string[], options: string[]) =>
  names
    .map((name, index) => `${name.trim().toLowerCase()}=${(options[index] ?? "").trim().toLowerCase()}`)
    .sort()
    .join("|");

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

const fill = (group: ProductGroup | null) => {
  form.name = group?.name ?? "";
  form.desc = group?.desc ?? "";
  form.imageUrl = group?.imageUrl ?? "";
  form.isActive = group?.isActive ?? true;
  bulk.price = "";
  bulk.unit = "";
  submitted.value = false;
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
  attributes.value = (group?.attributes ?? []).map((item) => ({
    uid: nextUid++,
    name: item.name,
    values: [...item.values],
    draft: "",
  }));
  // The watcher only fires on a change; build the rows for this group now.
  rows.value = buildRows(names, combos.value);
};

watch(
  () => [props.open, props.groupId, groupQuery.data.value] as const,
  ([open, groupId, group]) => {
    if (!open) return;
    if (!groupId) fill(null);
    else if (group && group.id === groupId) fill(group);
  },
  { immediate: true }
);

const addAttribute = () => {
  attributes.value.push({ uid: nextUid++, name: "", values: [], draft: "" });
};

const removeAttribute = (index: number) => {
  attributes.value.splice(index, 1);
};

const moveAttribute = (index: number, step: number) => {
  const list = attributes.value;
  const [item] = list.splice(index, 1);
  if (item) list.splice(index + step, 0, item);
};

const commitDraft = (attribute: AttributeForm) => {
  for (const part of attribute.draft.split(",")) {
    const value = part.trim();
    if (value && !attribute.values.some((existing) => same(existing, value))) attribute.values.push(value);
  }
  attribute.draft = "";
};

// Enter or a comma closes the value being typed.
const onValueKey = (event: KeyboardEvent, attribute: AttributeForm) => {
  if (event.key !== "Enter" && event.key !== ",") return;
  event.preventDefault();
  commitDraft(attribute);
};

const removeValue = (attribute: AttributeForm, value: string) => {
  attribute.values = attribute.values.filter((item) => item !== value);
};

/** Known values of an attribute with the same name, not yet picked. */
const suggestedValues = (attribute: AttributeForm) =>
  (knownAttributes.value.find((known) => same(known.name, attribute.name))?.values ?? []).filter(
    (value) => !attribute.values.some((picked) => same(picked, value))
  );

const attributeError = (attribute: AttributeForm): string => {
  if (!attribute.name.trim()) return t("petCare.common.required");
  if (attributes.value.filter((item) => same(item.name, attribute.name)).length > 1) return t("products.attributes.duplicate");
  if (!attribute.values.length) return t("products.attributes.needValue");
  return "";
};

const applyBulk = () => {
  for (const row of rows.value) {
    if (bulk.price.trim()) row.price = bulk.price;
    if (bulk.unit.trim()) row.unit = bulk.unit.trim();
  }
};

const submit = async () => {
  for (const attribute of attributes.value) commitDraft(attribute);
  submitted.value = true;
  if (!form.name.trim()) return;
  if (attributes.value.some((attribute) => attributeError(attribute))) return;
  if (rows.value.some((row) => !row.unit.trim())) return;

  try {
    await mutation.mutateAsync({
      id: props.groupId ?? undefined,
      name: form.name,
      desc: form.desc,
      imageUrl: form.imageUrl,
      isActive: form.isActive,
      attributes: attributes.value.map((attribute) => ({ name: attribute.name.trim(), values: attribute.values })),
      variants: rows.value.map((row) => ({
        id: row.id,
        options: row.options,
        sku: row.sku,
        barcode: row.barcode,
        unit: row.unit,
        price: parseAmount(row.price),
        trackStock: row.trackStock,
        isActive: row.isActive,
        imageUrl: row.imageUrl,
      })),
    });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
