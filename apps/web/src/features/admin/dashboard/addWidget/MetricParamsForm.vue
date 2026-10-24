<template>
  <div class="space-y-4">
    <label v-if="def.views.length > 1" class="block space-y-1 text-sm">
      <span class="font-medium">{{ $t("dashboard.add.view") }}</span>
      <select v-model="form.view" class="h-9 w-full rounded-md border bg-white px-2">
        <option v-for="view in def.views" :key="view" :value="view">{{ $t(`dashboard.add.views.${view}`) }}</option>
      </select>
    </label>

    <label v-for="(allowed, name) in def.params ?? {}" :key="name" class="block space-y-1 text-sm">
      <span class="font-medium">{{ $t(`dashboard.add.param.${name}`) }}</span>
      <select v-model="form.params[name]" class="h-9 w-full rounded-md border bg-white px-2">
        <option v-for="value in allowed" :key="value" :value="value">{{ optionLabel(name, value) }}</option>
      </select>
    </label>

    <RangeFields v-if="def.usesRange" v-model:range="form.range" :fallback="def.defaultRange ?? 'today'" />

    <label class="block space-y-1 text-sm">
      <span class="font-medium">{{ $t("dashboard.add.title") }}</span>
      <input v-model="form.title" maxlength="60" :placeholder="$t(def.labelKey)" class="h-9 w-full rounded-md border bg-white px-2" />
    </label>

    <label v-if="canCompare" class="flex items-center gap-2 text-sm">
      <input v-model="form.compare" type="checkbox" class="size-4" />
      {{ $t("dashboard.add.compare") }}
    </label>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import RangeFields from "../range/RangeFields.vue";
import { supportsCompare } from "../metrics/params";
import type { MetricDef } from "../metrics/types";
import type { MetricForm } from "./addWidgetItem";

const props = defineProps<{ def: MetricDef }>();
const form = defineModel<MetricForm>("form", { required: true });
const { t, te } = useI18n();

const canCompare = computed(() => supportsCompare(props.def, form.value.params));
const optionLabel = (name: string, value: string | number): string => {
  if (typeof value === "number") return te(`dashboard.param.${name}`) ? t(`dashboard.param.${name}`, { n: value }) : String(value);
  return te(`dashboard.param.${name}.${value}`) ? t(`dashboard.param.${name}.${value}`) : value;
};
</script>
