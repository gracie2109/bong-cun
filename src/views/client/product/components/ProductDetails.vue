<template>
  <section class="grid gap-6 border-t pt-8 lg:grid-cols-[1fr_320px]">
    <div class="space-y-2">
      <h2 class="text-xl font-semibold">{{ $t("client.product.description") }}</h2>
      <p v-if="group.desc" class="whitespace-pre-line text-muted-foreground">{{ group.desc }}</p>
      <p v-else class="text-muted-foreground">{{ $t("client.product.noDescription") }}</p>
    </div>
    <dl class="space-y-3 self-start rounded-xl bg-muted/40 p-5 text-sm">
      <div v-for="row in rows" :key="row.label" class="flex justify-between gap-4">
        <dt class="text-muted-foreground">{{ row.label }}</dt>
        <dd class="text-right font-medium">{{ row.value }}</dd>
      </div>
    </dl>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import type { ProductGroup, ProductVariant } from "@/repositories/products";

const props = defineProps<{ group: ProductGroup; variant: ProductVariant | undefined }>();
const { t } = useI18n();

const rows = computed(() =>
  [
    { label: t("client.product.brand"), value: props.group.brandName },
    { label: t("client.product.category"), value: props.group.categoryName },
    { label: t("client.product.unit"), value: props.variant?.unit ?? props.group.variants[0]?.unit },
    { label: t("client.product.sku"), value: props.variant?.sku },
  ].filter((row): row is { label: string; value: string } => Boolean(row.value))
);
</script>
