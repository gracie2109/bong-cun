<template>
  <div class="input_pw flex relative">
    <Input class="relative" v-model:model-value="value" @update:model-value="updateValue"
      :placeholder="props.placeholder" :readOnly="props.readonly ?? false" :disabled="props.disabled ?? false" />
    <div class="absolute right-3 h-full grid place-items-center cursor-pointer" v-if="value">
      <span class="">{{ props.contentValue }}</span>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { onMounted, ref, watch, watchEffect } from "vue";
import { Input } from "@/components/ui/input";
import type { FormContext } from "vee-validate";

const props = defineProps<{
  placeholder: string;
  contentValue: any;
  form: FormContext<any>;
  name: string;
  readonly?: boolean;
  disabled?: boolean;
  defaultValue?: number
}>();

const emits = defineEmits(["updateValue"]);
const value = ref("");

function updateValue() {
  emits("updateValue", value.value);
  if (props.form && props.name) {
    props.form.setFieldValue(props.name, value.value);
  }
}

watchEffect(() => {
  if (props.form && props.name) {
    value.value=props.form.values[props.name];
  }
})
</script>
