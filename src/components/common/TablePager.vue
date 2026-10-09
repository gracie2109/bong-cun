<template>
  <nav class="flex items-center gap-1 text-xs text-muted-foreground" :aria-label="$t('common.table.pagination')">
    <Button
      variant="ghost"
      size="icon"
      class="size-8"
      :aria-label="$t('common.table.first')"
      :disabled="page <= 1 || loading"
      @click="page = 1"
    >
      <ChevronsLeft class="size-4" />
    </Button>
    <Button
      variant="ghost"
      size="icon"
      class="size-8"
      :aria-label="$t('common.table.prev')"
      :disabled="page <= 1 || loading"
      @click="page -= 1"
    >
      <ChevronLeft class="size-4" />
    </Button>
    <span class="px-2 sm:hidden">{{ $t("petCare.common.pageOf", { page, pages: pageCount }) }}</span>
    <span class="hidden items-center gap-1 sm:flex">
      <template v-for="item in items" :key="item">
        <span v-if="typeof item === 'string'" class="w-6 text-center">…</span>
        <Button
          v-else
          :variant="item === page ? 'default' : 'ghost'"
          size="icon"
          class="size-8 text-xs"
          :aria-current="item === page ? 'page' : undefined"
          :disabled="loading"
          @click="page = item"
        >
          {{ item }}
        </Button>
      </template>
    </span>
    <Button
      variant="ghost"
      size="icon"
      class="size-8"
      :aria-label="$t('common.table.next')"
      :disabled="page >= pageCount || loading"
      @click="page += 1"
    >
      <ChevronRight class="size-4" />
    </Button>
    <Button
      variant="ghost"
      size="icon"
      class="size-8"
      :aria-label="$t('common.table.last')"
      :disabled="page >= pageCount || loading"
      @click="page = pageCount"
    >
      <ChevronsRight class="size-4" />
    </Button>
  </nav>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { pageWindow } from "@/lib/listing";

const props = defineProps<{ pageCount: number; loading?: boolean }>();

/** 1-based page number. */
const page = defineModel<number>("page", { required: true });

const items = computed(() => pageWindow(page.value, props.pageCount));
</script>
