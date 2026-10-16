<template>
  <Button type="button" size="sm" :variant="onlyNew ? 'default' : 'outline'" class="rounded-full" @click="onlyNew = !onlyNew">
    {{ $t("pageFields.customers.filterNew", { days: NEW_CUSTOMER_DAYS }) }}
  </Button>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { NEW_CUSTOMER_DAYS } from "./customer-stats";

const onlyNew = defineModel<boolean>({ required: true });
</script>
