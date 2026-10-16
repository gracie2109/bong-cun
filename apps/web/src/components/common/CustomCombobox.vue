<script lang="ts" setup>
import {computed, onMounted, ref, watch} from 'vue'
import {Button} from '@/components/ui/button'
import {Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList,} from '@/components/ui/command'
import {Popover, PopoverContent, PopoverTrigger,} from '@/components/ui/popover'
import {Badge} from '@/components/ui/badge'
import type {SelectOptionValue} from "@/types";
import {ChevronDown, ChevronsUpDown, X} from "lucide-vue-next";
import {Checkbox} from '@/components/ui/checkbox'

type TCheckbox = boolean | 'indeterminate'
const dataValue = ref<string[]>([]);
const dataValueWithLabel = ref(new Map())
const optionValue = ref<SelectOptionValue[]>([])
const renderValue = ref([])
const open = ref(false);
const isAllChecked = ref<TCheckbox>(false);


const props = defineProps<{
  placeholder: string,
  options: SelectOptionValue[],
  isMulti?: boolean,
  value?: any,
  searchLabel?: boolean,
  maxTagCount?: number | 'responsive',
  showClear?: boolean,
  showCheckbox?: boolean,
  hasAll?: boolean
}>();

const emit = defineEmits(['selectOption'])
const searchField = computed(() => props.searchLabel ? 'label' : 'value');
const maxTagCount = computed(() => {
  if (props?.maxTagCount) {
    if (props?.maxTagCount === 'responsive') return 'responsive'
    else return props?.maxTagCount
  }
});


function handleSelect(data: any) {
  if (typeof data === 'string') {
    if (props.hasAll && (data === 'all' || data === 'All')) {
      dataValue.value = dataValue.value.length > 0 ? [] : optionValue.value.map((item: any) => item.value)
    } else {
      if (searchField.value === 'value') {
        searchValue(data)
      } else {
        searchLabel(data)
      }
    }

  }
  const dataPayload = props.isMulti ? dataValue.value : dataValue.value[0];
  const isAll = ['All', 'all'].some(itemB => dataValue.value.includes(itemB.toLowerCase()));
  emit('selectOption', !isAll ? dataPayload : dataPayload.slice(1));
}


function searchLabel(data: string) {
  if (!props.isMulti) {
    const getValue = props.options.find(i => i?.label === data)?.value;
    if (getValue) {
      const itemExist = dataValue.value?.includes(getValue);
      if (!itemExist) dataValue.value = [getValue];
      else dataValue.value = dataValue.value.filter((i) => i !== getValue);
    }
  } else {
    const getValue = props.options.find(i => i?.label === data)?.value;
    if (getValue) {
      const itemExist = dataValue.value?.includes(getValue);
      if (!itemExist) dataValue.value = dataValue.value ? [...dataValue.value, getValue] : [getValue];
      else dataValue.value = dataValue.value.filter((i) => i !== getValue);
    }
  }
}

function searchValue(data: string) {
  if (props.isMulti) {
    const findItem = dataValue.value.find((i) => i === data);
    if (!findItem) dataValue.value = dataValue.value ? [...dataValue.value, data] : [data];
    else dataValue.value = dataValue.value.filter((i) => i !== data);
  } else {
    dataValue.value = [data];
  }
}


function handleClearValue(e: MouseEvent) {
  e.stopPropagation();
  e.preventDefault();
  if (props.showClear) {
    dataValue.value = []
  }
  emit('selectOption', []);
  open.value = false;
}


onMounted(() => {
  if (props.options) {
    props.options.map((i) => {
      dataValueWithLabel.value = dataValueWithLabel.value.set(i.value, i.label)
    })
  }

  if (props.value) {
    dataValue.value = props.value
  }


  if (props.hasAll) {
    const options = props.options
    optionValue.value = [
      {
        label: 'All',
        value: 'all'
      },
      ...options,
    ]
  } else {
    optionValue.value = [...props.options]
  }
});


watch(() => dataValue.value, () => {
  if (props.hasAll) {
    const isAll = ['All', 'all'].some(itemB => dataValue.value.includes(itemB.toLowerCase()));
    //@ts-ignore
    renderValue.value = isAll ? dataValue.value.slice(1) : dataValue.value;

    isAllChecked.value = dataValue.value.length - 1 === props.options.length ? true : dataValue.value.length - 1 > 0 ? 'indeterminate' : false
    ;
  }
})


</script>

<template>
  <div class="mt-12">
    <Popover v-model:open="open" class="mt-24">
      <PopoverTrigger as-child>
        <Button
            :aria-expanded="open"
            class="h-auto w-full flex justify-between"
            role="combobox"
            variant="outline"
        >
          <div v-if="dataValue.length > 0"
               class="w-full  gap-y-1 flex flex-wrap h-auto"
          >
            <Badge v-for="i of renderValue" v-if="props.isMulti" class="mr-0.5 flex justify-between gap-2"
                   variant="secondary">
              <span>{{ dataValueWithLabel.get(i) }}</span>
            </Badge>
            <div v-else>{{ dataValueWithLabel.get(dataValue[0]) }}</div>
          </div>
          <span v-else>Select framework...</span>
          <div class="flex flex-end items-center gap-2">
            <div v-show="props.showClear  && dataValue.length > 0"
                 class="bg-[#dcdcdc] w-4 h-4 grid place-items-center rounded-full"
                 @click="(e) => handleClearValue(e)"
            >
              <X class="w-3 h-3"/>
            </div>
            <ChevronsUpDown class="ml-2 h-4 w-4 shrink-0 opacity-50"/>
          </div>

        </Button>
      </PopoverTrigger>
      <PopoverContent class=" p-0 w-[500px] z-[1000] bg-white">
        <Command>
          <CommandInput :placeholder="props.placeholder" as="input" class="h-9"/>
          <CommandEmpty>No item found.</CommandEmpty>
          <CommandList>
            <CommandGroup>
              <CommandItem
                  v-for="item  in optionValue"
                  :key="item[searchField]"
                  :class="{'bg-[#f5f5f5]':  dataValue.includes(item.value)}"
                  :value="item[searchField]"
                  class="w-full cursor-pointer"
                  @select="(ev) => {
                    handleSelect(ev.detail.value)
                   }"
              >
                <div v-if="props.showCheckbox" class="flex items-center  space-x-2">
                  <Checkbox v-if="item.value === 'all' || item.value === 'All'"
                            :id="item[searchField]"
                            :checked="isAllChecked"
                  />
                  <Checkbox v-else :id="item[searchField]" :checked="dataValue.includes(item.value)"/>
                  <label
                      :class="{'font-semibold': dataValue.includes(item.value)}"
                      class="text-sm  leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
                      for="terms"
                  >
                    {{ item.label }}
                  </label>
                </div>
                <div v-else class="flex items-center justify-between w-full">
                  <p :class="{'font-semibold':  dataValue.includes(item.value)}"> {{ item.label }}</p>

                  <ChevronDown :class="{'hidden':  !dataValue.includes(item.value)}" class="w-4 h-4"/>
                </div>
              </CommandItem>
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  </div>
</template>

