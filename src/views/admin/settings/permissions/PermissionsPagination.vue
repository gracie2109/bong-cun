<template>
  <div class="flex flex-wrap items-center justify-between gap-3 border-t px-4 py-3 text-sm text-muted-foreground">
    <div class="flex items-center gap-3">
      <span>{{ $t("rbac.permissions.pageRange", { from, to, total }) }}</span>
      <Select v-model="pageSizeValue">
        <SelectTrigger class="h-8 w-28" :aria-label="$t('rbac.permissions.perPage')"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem v-for="size in PAGE_SIZES" :key="size" :value="String(size)">
            {{ $t("rbac.permissions.perPageOption", { n: size }) }}
          </SelectItem>
        </SelectContent>
      </Select>
    </div>
    <div class="flex items-center gap-1">
      <Button variant="ghost" size="icon" class="size-8" :disabled="page === 1" @click="page--">
        <ChevronLeft class="size-4" />
      </Button>
      <Button
        v-for="n in pageCount"
        :key="n"
        :variant="n === page ? 'default' : 'ghost'"
        size="icon"
        class="size-8"
        @click="page = n"
      >
        {{ n }}
      </Button>
      <Button variant="ghost" size="icon" class="size-8" :disabled="page === pageCount" @click="page++">
        <ChevronRight class="size-4" />
      </Button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { ChevronLeft, ChevronRight } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { PAGE_SIZES } from "./usePermissionsFilter";

defineProps<{ from: number; to: number; total: number; pageCount: number }>();

const page = defineModel<number>("page", { required: true });
const pageSizeValue = defineModel<string>("pageSize", { required: true });
</script>
