import { cva, type VariantProps } from 'class-variance-authority';
import type { PrimitiveProps } from 'reka-ui';
import type { HTMLAttributes } from 'vue';

export { default as Input } from './Input.vue';


export const inputVariants = cva(
    'inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50',
    {
      variants: {
        variant: {
          default: '',
        },
        size: {
          default: 'h-9',
          lg: 'h-12',
          sm: 'h-10'
        },
      },
      defaultVariants: {
        variant: 'default',
        size: 'lg',
      },
    },
  )


  export type InputVariants = VariantProps<typeof inputVariants>;

  export interface InputProps {
    variant?: InputVariants['variant']
    size?:InputVariants['size']
    class?: HTMLAttributes['class'],
    defaultValue?: string | number;
    modelValue?: string | number;
  }