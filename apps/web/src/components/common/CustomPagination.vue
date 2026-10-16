<template>
  <div class="pagination_wrap w-full flex justify-between items-center">
    <div class="left_show_selected flex items-center gap-3">
      <span class="inline-block text-sm font-semibold">{{ $t('common.row_per_page') }}</span>
      <Select
        :model-value="`${props.pageSize}`"
        @update:model-value="(vl) => $emit('updatePageSize', Number(vl))"
      >
        <SelectTrigger class="h-8 w-[70px]">
          <SelectValue :placeholder="`${props.pageSize}`" />
        </SelectTrigger>
        <SelectContent side="top">
          <SelectItem
            v-for="pageSize in PAGE_SIZES"
            :key="pageSize"
            :value="`${pageSize}`"
          >
            {{ pageSize }}
          </SelectItem>
        </SelectContent>
      </Select>
    </div>

    <div class="flex gap-3 items-center" v-if="totalPage > 1">
      <Button
        size="xss"
        v-for="(i, j) in totalPage"
        :key="j"
        v-if="totalPage"
        @click="
          () => {
            $emit('onChange', i);
          }
        "
        :variant="props.pageCurrent !== +j + 1 ? 'outline' : 'default'"
      >
        {{ i }}
      </Button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {PAGE_SIZES} from "@/lib/constants"

const props = defineProps<{
  totalRecord: number;
  pageCurrent: number;
  pageSize: number;
}>();

const emits = defineEmits(["onChange","updatePageSize"]);
const totalPage = computed(() => Math.ceil(props.totalRecord / props.pageSize));
</script>
