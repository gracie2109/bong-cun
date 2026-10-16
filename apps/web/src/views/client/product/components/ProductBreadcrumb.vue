<template>
  <nav :aria-label="$t('client.catalog.breadcrumb')" class="text-sm text-muted-foreground">
    <ol class="flex flex-wrap items-center gap-x-2 gap-y-1">
      <li><RouterLink :to="{ name: 'home' }" class="hover:text-foreground">{{ $t("client.nav.home") }}</RouterLink></li>
      <li aria-hidden="true" class="opacity-50">/</li>
      <li><RouterLink :to="{ name: 'products' }" class="hover:text-foreground">{{ $t("client.nav.products") }}</RouterLink></li>
      <template v-if="categoryName">
        <li aria-hidden="true" class="opacity-50">/</li>
        <li>
          <RouterLink :to="{ name: 'products', query: { category: categoryId } }" class="hover:text-foreground">
            {{ parentName ? `${parentName} · ${categoryName}` : categoryName }}
          </RouterLink>
        </li>
      </template>
      <li aria-hidden="true" class="hidden opacity-50 sm:block">/</li>
      <li class="hidden max-w-[28ch] truncate text-foreground sm:block" aria-current="page">{{ name }}</li>
    </ol>
  </nav>
</template>

<script lang="ts" setup>
defineProps<{ name: string; categoryId: string | null; categoryName: string | null; parentName: string | null }>();
</script>
