<script setup lang="ts">
import { type HTMLAttributes, computed } from 'vue'
import {
  SwitchRoot,
  type SwitchRootProps,
  SwitchThumb,
  useForwardProps,
} from 'reka-ui'
import { cn } from '@/lib/utils'

// reka-ui models the state as `modelValue`; the app keeps radix-vue's `checked` / `update:checked`.
const props = withDefaults(
  defineProps<Omit<SwitchRootProps, 'modelValue' | 'defaultValue'> & {
    class?: HTMLAttributes['class']
    checked?: boolean
    defaultChecked?: boolean
  }>(),
  { checked: undefined, defaultChecked: undefined },
)
const emit = defineEmits<{ 'update:checked': [value: boolean] }>()

const delegatedProps = computed(() => {
  const { class: _, checked: __, defaultChecked: ___, ...delegated } = props

  return delegated
})

const forwarded = useForwardProps(delegatedProps)
</script>

<template>
  <SwitchRoot
    v-bind="forwarded"
    :model-value="props.checked"
    :default-value="props.defaultChecked"
    @update:model-value="(value) => emit('update:checked', value)"
    :class="cn(
      'peer inline-flex h-5 w-9 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:cursor-not-allowed disabled:opacity-50 data-[state=checked]:bg-primary data-[state=unchecked]:bg-input',
      props.class,
    )"
  >
    <SwitchThumb
      :class="cn('pointer-events-none block h-4 w-4 rounded-full bg-background shadow-lg ring-0 transition-transform data-[state=checked]:translate-x-4 data-[state=unchecked]:translate-x-0')"
    />
  </SwitchRoot>
</template>
