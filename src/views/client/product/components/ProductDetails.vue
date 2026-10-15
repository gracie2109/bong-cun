<template>
  <section class="mt-14 grid gap-8 border-t pt-10 md:mt-20 lg:grid-cols-[1fr_360px] lg:gap-14">
    <div>
      <h2 class="text-xl font-bold md:text-2xl">{{ $t("client.product.description") }}</h2>
      <p v-if="group.desc" class="mt-4 max-w-[68ch] whitespace-pre-line leading-relaxed text-foreground/80">{{ group.desc }}</p>
      <p v-else class="mt-4 text-muted-foreground">{{ $t("client.product.noDescription") }}</p>
    </div>
    <div>
      <h2 class="text-xl font-bold md:text-2xl">{{ $t("client.product.specs") }}</h2>
      <dl class="mt-4 divide-y rounded-2xl border bg-white text-sm">
        <div v-for="row in rows" :key="row.label" class="flex justify-between gap-4 px-4 py-3">
          <dt class="text-muted-foreground">{{ row.label }}</dt>
          <dd class="text-right font-medium">{{ row.value }}</dd>
        </div>
      </dl>
    </div>
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
