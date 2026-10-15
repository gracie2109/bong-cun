<template>
  <Select v-model="model">
    <SelectTrigger :aria-label="$t('medical.book.type')"><SelectValue :placeholder="$t('medical.book.typePlaceholder')" /></SelectTrigger>
    <SelectContent>
      <SelectItem v-for="type in types" :key="type.id" :value="type.id">{{ type.name }}</SelectItem>
    </SelectContent>
  </Select>
</template>

<script lang="ts" setup>
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { VaccineType } from "@/types/medical";

defineProps<{ types: VaccineType[] }>();
const model = defineModel<string>({ required: true });
</script>
