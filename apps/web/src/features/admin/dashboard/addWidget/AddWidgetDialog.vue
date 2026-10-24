<template>
  <AppDialog
    :open="open"
    :title="def ? $t(def.labelKey) : $t('dashboard.add.dialogTitle')"
    size="md"
    :hide-footer="!def"
    :ok-text="$t('dashboard.add.add')"
    :cancel-text="def ? $t('dashboard.add.back') : $t('common.cancel')"
    @update:open="(value) => !value && close()"
    @ok="confirm"
    @cancel="onCancel"
  >
    <MetricPicker v-if="!def" :scope="scope" :missing-fixed="missingFixed" @pick-metric="choose" @pick-fixed="emit('addFixed', $event)" />
    <MetricParamsForm v-else v-model:form="form" :def="def" />
  </AppDialog>
</template>

<script lang="ts" setup>
import { ref, watch } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import type { DashboardScope } from "../kit/types";
import type { MetricDef } from "../metrics/types";
import { defaultForm, type MetricForm } from "./addWidgetItem";
import MetricParamsForm from "./MetricParamsForm.vue";
import MetricPicker from "./MetricPicker.vue";

const props = defineProps<{ open: boolean; scope: DashboardScope; missingFixed: string[] }>();
const emit = defineEmits<{ close: []; addMetric: [def: MetricDef, form: MetricForm]; addFixed: [type: string] }>();

const def = ref<MetricDef | null>(null);
const form = ref<MetricForm>({ view: "kpi", params: {}, title: "", compare: false });

const choose = (picked: MetricDef) => {
  def.value = picked;
  form.value = defaultForm(picked);
};
const close = () => {
  def.value = null;
  emit("close");
};
// "Back" from the settings step returns to the list; from the list it closes the dialog.
const onCancel = () => (def.value ? (def.value = null) : close());
const confirm = () => {
  if (!def.value) return;
  emit("addMetric", def.value, { ...form.value, params: { ...form.value.params } });
  def.value = null;
};
watch(() => props.open, (value) => !value && (def.value = null));
</script>
