<template>
  <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
    <div class="relative min-w-60 flex-1">
      <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      <Input v-model="search" class="pl-9" :placeholder="$t('pageFields.customers.searchPlaceholder')" />
    </div>
    <Button
      type="button"
      size="sm"
      :variant="onlyNew ? 'default' : 'outline'"
      class="rounded-full"
      @click="onlyNew = !onlyNew"
    >
      {{ $t("pageFields.customers.filterNew", { days: NEW_CUSTOMER_DAYS }) }}
    </Button>
    <div class="flex items-center gap-2 text-sm text-muted-foreground">
      {{ $t("pageFields.customers.sortBy") }}
      <Select v-model="sort">
        <SelectTrigger class="w-44"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem v-for="option in SORT_OPTIONS" :key="option" :value="option">
            {{ $t(`pageFields.customers.sort.${option}`) }}
          </SelectItem>
        </SelectContent>
      </Select>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Search } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { USER_SORT, type UserSort } from "@/repositories/users";
import { NEW_CUSTOMER_DAYS } from "./customer-stats";

const SORT_OPTIONS = Object.values(USER_SORT);

const search = defineModel<string>("search", { required: true });
const onlyNew = defineModel<boolean>("onlyNew", { required: true });
const sort = defineModel<UserSort>("sort", { required: true });
</script>
