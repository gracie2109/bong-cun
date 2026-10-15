<script setup lang="ts">
import { type HTMLAttributes, computed } from 'vue'
import type { CheckboxRootProps } from 'reka-ui'
import { CheckboxIndicator, CheckboxRoot, useForwardProps } from 'reka-ui'
import { CheckIcon } from '@radix-icons/vue'
import { cn } from '@/lib/utils'

// reka-ui models the state as `modelValue`; the app keeps radix-vue's `checked` / `update:checked`.
type CheckedState = boolean | 'indeterminate'
const props = withDefaults(
  defineProps<Omit<CheckboxRootProps, 'modelValue' | 'defaultValue'> & {
    class?: HTMLAttributes['class']
    checked?: CheckedState
    defaultChecked?: CheckedState
  }>(),
  { checked: undefined, defaultChecked: undefined },
)
const emit = defineEmits<{ 'update:checked': [value: CheckedState] }>()

const delegatedProps = computed(() => {
  const { class: _, checked: __, defaultChecked: ___, ...delegated } = props

  return delegated
})

const forwarded = useForwardProps(delegatedProps)
</script>

<template>
  <CheckboxRoot
    v-bind="forwarded"
    :model-value="props.checked"
    :default-value="props.defaultChecked"
    @update:model-value="(value) => emit('update:checked', value)"
    :class="
      cn('peer h-5 w-5 shrink-0 rounded-sm border border-primary shadow focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50 data-[state=checked]:bg-primary data-[state=checked]:text-primary-foreground',
         props.class)"
  >
    <CheckboxIndicator class="flex h-full w-full items-center justify-center text-current">
      <slot>
        <CheckIcon class="h-4 w-4" />
      </slot>
    </CheckboxIndicator>
  </CheckboxRoot>
</template>
