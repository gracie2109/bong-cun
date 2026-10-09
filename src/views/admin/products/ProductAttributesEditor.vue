<template>
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
      <p v-if="submitted && error(attribute)" class="text-sm text-red-600">{{ error(attribute) }}</p>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { useI18n } from "vue-i18n";
import { ArrowDown, ArrowUp, Plus, Trash2, X } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  attributeError,
  commitDraft,
  newAttribute,
  same,
  type AttributeForm,
} from "./productVariantForm";

const props = defineProps<{
  /** Attributes already used in the shop, offered as suggestions. */
  knownAttributes: { id: string; name: string; values: string[] }[];
  /** Whether a save was attempted, which shows the errors. */
  submitted: boolean;
}>();

const attributes = defineModel<AttributeForm[]>("attributes", { required: true });
const { t } = useI18n();

const error = (attribute: AttributeForm): string => attributeError(attributes.value, attribute, t);

const addAttribute = () => {
  attributes.value.push(newAttribute());
};

const removeAttribute = (index: number) => {
  attributes.value.splice(index, 1);
};

const moveAttribute = (index: number, step: number) => {
  const [item] = attributes.value.splice(index, 1);
  if (item) attributes.value.splice(index + step, 0, item);
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
const suggestedValues = (attribute: AttributeForm): string[] =>
  (props.knownAttributes.find((known) => same(known.name, attribute.name))?.values ?? []).filter(
    (value) => !attribute.values.some((picked) => same(picked, value))
  );
</script>
