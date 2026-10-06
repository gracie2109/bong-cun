<template>
  <FormField :name="name">
    <template #default="scope">
      <FormItem>
        <FormControl class="relative rounded-none">
          <div class="relative">
            <input
              type="text"
              class="text-sm w-full relative rounded-none"
              :placeholder="placeholder"
              v-bind="scope"
              :value="modelValue"
              @input="onInput"
              :class="{
                'invalid p-invalid': isInValid
              }"
            />
            <div
              class="absolute right-0 bottom-2 cursor-pointer"
              v-if="isInValid"
            >
              <Popover>
                <PopoverTrigger> <InfoIcon class="h-5 w-5" /></PopoverTrigger>
                <PopoverContent>
                  <p>{{ error }}</p>
                 
                  <PopoverArrow />
                  </PopoverContent
                >
              </Popover>
            </div>
          </div>
        </FormControl>
      </FormItem>
    </template>
  </FormField>
</template>
<script lang="ts" setup>
import { ref, defineProps, defineEmits } from "vue";

import { InfoIcon } from "lucide-vue-next";
import { Popover, PopoverContent, PopoverTrigger } from "./ui/popover";
import { FormControl, FormField, FormItem } from "./ui/form";
import { PopoverArrow, PopoverClose } from "radix-vue";

defineProps<{
  name: string;
  placeholder: string;
  error: any;
  isInValid: boolean;
  modelValue: string;
}>();
const openTooltip = ref(false);
const emit = defineEmits<{
  (e: "update:modelValue", value: string): void;
}>();
const onInput = (event: Event) => {
  const input = event.target as HTMLInputElement;
  emit("update:modelValue", input.value);
};
</script>

<style scoped>
.invalid {
  border-bottom: 1px solid red !important;
}
input {
  height: 52px;
  padding-right: 5px;
  color: #582e15;
  background: transparent !important;
  border: none;
  border-bottom: 1px solid #e3c2af;
  outline: none;
  position: relative;
}

.textarea {
  color: #582e15;
  background: transparent;
  border: none;
  border-bottom: 1px solid #e3c2af;
  outline: none;
  width: 100%;
  height: 52px;
}

input:-webkit-autofill {
  background: transparent !important;
  -webkit-box-shadow: 0 0 0px 1000px transparent inset !important;
  box-shadow: 0 0 0px 1000px transparent inset !important;
  transition: background-color 5000s ease-in-out 0s;
}
/* Firefox */
input:-moz-autofill {
  background: transparent !important;
  box-shadow: 0 0 0px 1000px transparent inset !important;
}

input:-webkit-autofill:focus {
  background: transparent !important;
  -webkit-box-shadow: 0 0 0px 1000px transparent inset !important;
  box-shadow: 0 0 0px 1000px transparent inset !important;
}
</style>
