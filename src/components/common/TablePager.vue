<template>
  <div class="flex items-center gap-1 text-xs text-muted-foreground">
    <Button
      variant="ghost"
      size="icon"
      class="size-7"
      :disabled="page <= 1 || loading"
      @click="page -= 1"
    >
      <ChevronLeft class="size-4" />
    </Button>
    <span>{{ $t("petCare.common.pageOf", { page, pages: pageCount }) }}</span>
    <Button
      variant="ghost"
      size="icon"
      class="size-7"
      :disabled="page >= pageCount || loading"
      @click="page += 1"
    >
      <ChevronRight class="size-4" />
    </Button>
  </div>
</template>

<script lang="ts" setup>
import { ChevronLeft, ChevronRight } from "lucide-vue-next";
import { Button } from "@/components/ui/button";

defineProps<{ pageCount: number; loading?: boolean }>();

/** 1-based page number. */
const page = defineModel<number>("page", { required: true });
</script>
