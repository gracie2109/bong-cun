<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ShoppingBag class="size-4 text-primary" />
      {{ $t("shop.admin.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <ShopOrdersNav />

      <div class="space-y-3 rounded-xl border bg-white p-3">
        <div class="relative">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('shop.admin.searchPlaceholder')" />
        </div>
        <OrderTabs v-model:tab="tab" :counts="counts" />
      </div>

      <PagedTableCard
        class="min-h-0 flex-1"
        v-model:page="page.pageIndex"
        v-model:page-size="page.pageSize"
        :page-count="pageCount"
        :count="rows.length"
        :total="total"
        :scroll-x="900"
      >
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("shop.admin.cols.code") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("shop.admin.cols.placed") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("shop.admin.cols.customer") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("shop.admin.cols.method") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("shop.admin.cols.lines") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("shop.admin.cols.total") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("shop.admin.cols.status") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("shop.admin.cols.tracking") }}</th>
            </tr>
          </thead>
          <tbody>
            <TableStateRows :colspan="8" :pending="query.isPending.value" :empty="rows.length === 0" :empty-text="$t('shop.admin.empty')" />
            <OrderRow v-for="row in rows" :key="row.id" :order="row" @open="openId = row.id" />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <OrderSheet :order-id="openId" @close="openId = undefined" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { Search, ShoppingBag } from "lucide-vue-next";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Input } from "@/components/ui/input";
import { useOrdersPage } from "@/composables/shop/useOrdersPage";
import { ContentWrap, Header } from "@/views/admin/components";
import ShopOrdersNav from "../ShopOrdersNav.vue";
import OrderRow from "./components/OrderRow.vue";
import OrderSheet from "./components/OrderSheet.vue";
import OrderTabs from "./components/OrderTabs.vue";

const { tab, search, page, query, rows, total, pageCount, counts, openId } = useOrdersPage();
</script>
