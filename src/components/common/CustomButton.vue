<template>
  <Button
    :disabled="props.disabled || props.loading"
    :size="props.size || 'default'"
    :variant="props.variant || 'default'"
  >
    <Loader2 v-if="props.loading" class="w-4 h-4 mr-2 animate-spin"/>
    <slot name="icon"></slot>
    <span v-if="!hasIconSlot">{{ props.buttonText || '' }}</span>
  </Button>
</template>

<script lang="ts" setup>
import { useSlots } from 'vue';
import { Button, type ButtonVariants } from "@/components/ui/button";
import { Loader2 } from 'lucide-vue-next';

const slots = useSlots();
const hasIconSlot = !!slots.icon;

// Props are listed here rather than intersected with ButtonProps: the SFC compiler must then
// resolve "@/components/ui/button" itself, which fails in some dev setups.
type ICustomBtn = {
  disabled?: boolean;
  loading?: boolean;
  buttonText: string;
  icon?: any;
  variant?: ButtonVariants["variant"];
  size?: ButtonVariants["size"];
};

const props = defineProps<ICustomBtn>();

</script>
