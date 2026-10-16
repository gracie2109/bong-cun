<script lang="ts" setup>
import {
  NumberField,
  NumberFieldContent,
  NumberFieldDecrement,
  NumberFieldIncrement,
  NumberFieldInput,
} from '@/components/ui/number-field'
import {Label} from '@/components/ui/label';
import {computed} from "vue";

type InputField = 'Decimal' | 'Percentage' | 'Currency'

const props = defineProps<{
  label: string,
  type?: InputField,
  defaultValue?: string | number,
  disabled?: boolean,
  step?: number,
  min?: number,
  max?: number,
}>()

const options = computed(() => {
  let format = {};
  switch (props.type) {
    case 'Decimal':
      format = {
        signDisplay: 'exceptZero',
        minimumFractionDigits: 1,
      }
      break;
    case "Currency":
      format = {
        style: 'currency',
        currency: 'VND',
        currencyDisplay: 'code',
        currencySign: 'accounting',
      }
      break;

    case "Percentage":
      format = {
        style: 'percent',
      }
      break;
    default:
      break;
  }
  return format;

})

</script>

<template>
  <NumberField
      :disabled="props.disabled"
      :format-options="options"
      :max="props.max"
      :min="props.min || 0"
      :step='props.step || 1'
  >
    <Label>{{ props.label }}</Label>
    <NumberFieldContent>
      <NumberFieldDecrement/>
      <NumberFieldInput/>
      <NumberFieldIncrement/>
    </NumberFieldContent>
  </NumberField>
</template>