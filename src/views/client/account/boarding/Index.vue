<template>
  <div class="mx-auto w-full max-w-3xl space-y-4 pb-10">
    <div class="flex gap-1.5">
      <button
        v-for="item in BOARDING_SCOPES"
        :key="item"
        type="button"
        class="rounded-full border px-3 py-1 text-sm font-medium transition"
        :class="item === page.scope.value ? 'border-primary bg-primary text-white' : 'hover:border-primary/50'"
        @click="page.scope.value = item"
      >
        {{ $t(`client.boarding.scope.${item}`) }}
      </button>
    </div>

    <p v-if="page.loading.value" class="py-12 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="page.failed.value" class="py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("client.boarding.loadFailed") }}</p>
      <Button variant="outline" @click="page.retry">{{ $t("client.catalog.retry") }}</Button>
    </div>
    <div v-else-if="page.rows.value.length === 0" class="rounded-xl border border-dashed py-12 text-center text-muted-foreground">
      {{ $t(`client.boarding.empty.${page.scope.value}`) }}
    </div>
    <template v-else>
      <ul class="space-y-3" :class="page.fetching.value && 'opacity-60'">
        <StayCard v-for="stay in page.rows.value" :key="stay.id" :stay="stay" />
      </ul>
      <div class="flex items-center justify-between text-sm text-muted-foreground">
        <span>
          {{
            $t("common.table.range", {
              from: (page.page.value - 1) * page.pageSize + 1,
              to: (page.page.value - 1) * page.pageSize + page.rows.value.length,
              total: page.total.value,
            })
          }}
        </span>
        <TablePager v-model:page="page.page.value" :page-count="page.pageCount.value" :loading="page.fetching.value" />
      </div>
    </template>

    <p class="flex flex-wrap items-center gap-1 rounded-xl bg-muted/40 px-4 py-3 text-sm text-muted-foreground">
      <Phone class="size-4" aria-hidden="true" />
      {{ $t("client.boarding.callToBook") }}
      <a :href="`tel:${STORE_INFO.phone}`" class="font-medium text-primary">{{ STORE_INFO.phone }}</a>
    </p>
  </div>
</template>

<script lang="ts" setup>
import { Phone } from "lucide-vue-next";
import TablePager from "@/components/common/TablePager.vue";
import { Button } from "@/components/ui/button";
import { useMyBoarding } from "@/composables/account/useMyBoarding";
import { STORE_INFO } from "@/config/storeInfo";
import { BOARDING_SCOPES } from "@/types/account";
import StayCard from "./components/StayCard.vue";

const page = useMyBoarding();
</script>
