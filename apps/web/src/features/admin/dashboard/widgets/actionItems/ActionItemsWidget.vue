<template>
  <WidgetCard
    :title="$t('dashboard.actions.title')"
    :icon="ListChecks"
    :state="state"
    :empty-text="$t('dashboard.actions.empty')"
    @retry="refetch()"
  >
    <ul class="divide-y">
      <li v-for="row in rows" :key="row.key">
        <router-link :to="row.to" class="flex items-center justify-between gap-3 py-2 text-sm hover:text-primary">
          <span>{{ $t(`dashboard.actions.${row.key}`) }}</span>
          <span
            class="min-w-8 rounded-full px-2 py-0.5 text-center text-xs font-bold"
            :class="row.count ? 'bg-amber-100 text-amber-800' : 'bg-muted text-muted-foreground'"
          >
            {{ row.failed || row.count === null ? "—" : row.count }}
          </span>
        </router-link>
      </li>
    </ul>
  </WidgetCard>
</template>

<script lang="ts" setup>
import { ListChecks } from "lucide-vue-next";
import WidgetCard from "../../kit/WidgetCard.vue";
import { useActionItems } from "./useActionItems";

const { state, rows, refetch } = useActionItems();
</script>
