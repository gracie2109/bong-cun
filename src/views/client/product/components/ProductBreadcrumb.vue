<template>
  <Breadcrumb>
    <BreadcrumbList>
      <BreadcrumbItem>
        <BreadcrumbLink as-child><RouterLink :to="{ name: 'home' }">{{ $t("client.nav.home") }}</RouterLink></BreadcrumbLink>
      </BreadcrumbItem>
      <BreadcrumbSeparator />
      <BreadcrumbItem>
        <BreadcrumbLink as-child><RouterLink :to="{ name: 'products' }">{{ $t("client.nav.products") }}</RouterLink></BreadcrumbLink>
      </BreadcrumbItem>
      <template v-if="categoryName">
        <BreadcrumbSeparator />
        <BreadcrumbItem v-if="parentName"><span>{{ parentName }}</span></BreadcrumbItem>
        <BreadcrumbSeparator v-if="parentName" />
        <BreadcrumbItem>
          <BreadcrumbLink as-child>
            <RouterLink :to="{ name: 'products', query: { category: categoryId } }">{{ categoryName }}</RouterLink>
          </BreadcrumbLink>
        </BreadcrumbItem>
      </template>
      <BreadcrumbSeparator />
      <BreadcrumbItem><BreadcrumbPage class="line-clamp-1">{{ name }}</BreadcrumbPage></BreadcrumbItem>
    </BreadcrumbList>
  </Breadcrumb>
</template>

<script lang="ts" setup>
import { Breadcrumb, BreadcrumbItem, BreadcrumbLink, BreadcrumbList, BreadcrumbPage, BreadcrumbSeparator } from "@/components/ui/breadcrumb";

defineProps<{ name: string; categoryId: string | null; categoryName: string | null; parentName: string | null }>();
</script>
