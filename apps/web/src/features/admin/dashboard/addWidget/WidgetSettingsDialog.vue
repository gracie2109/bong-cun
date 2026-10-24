<template>
  <AppDialog
    :open="!!item"
    :title="def ? $t(def.labelKey) : ''"
    size="md"
    :ok-text="$t('dashboard.add.apply')"
    @update:open="(value) => !value && emit('close')"
    @ok="apply"
    @cancel="emit('close')"
  >
    <MetricParamsForm v-if="def" v-model:form="form" :def="def" />
  </AppDialog>
</template>

<script lang="ts" setup>
// Settings of a placed metric widget. The metric itself cannot change: remove the widget and add another.
import { computed, ref, watch } from "vue";
import type { SavedItem } from "@bongcun/core/dashboard";
import AppDialog from "@/components/common/AppDialog.vue";
import { resolveMetricConfig } from "../widgets/metric/metricConfig";
import { defaultForm, savedConfigOf, type MetricForm } from "./addWidgetItem";
import MetricParamsForm from "./MetricParamsForm.vue";

const props = defineProps<{ item: SavedItem | null }>();
const emit = defineEmits<{ close: []; apply: [form: MetricForm] }>();

const def = computed(() => (props.item ? (resolveMetricConfig(props.item.config)?.def ?? null) : null));
const form = ref<MetricForm>({ view: "kpi", params: {}, title: "", compare: false });
watch(
  () => props.item,
  (item) => {
    if (item && def.value) form.value = defaultForm(def.value, savedConfigOf(item));
  },
  { immediate: true }
);
const apply = () => emit("apply", { ...form.value, params: { ...form.value.params } });
</script>
