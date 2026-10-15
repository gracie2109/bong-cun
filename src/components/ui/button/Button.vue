<script setup lang="ts">
import { Primitive, type PrimitiveProps } from 'reka-ui'
import {  buttonVariants, type ButtonProps } from '.'
import { cn } from '@/lib/utils'

const props = withDefaults(defineProps<ButtonProps>(), {
  as: 'button',
})
</script>

<template>
  <Primitive
    :as="as"
    :as-child="asChild"
    :class="cn(buttonVariants({ variant, size }), props.class)"
  >
    <slot />
  </Primitive>
</template>
