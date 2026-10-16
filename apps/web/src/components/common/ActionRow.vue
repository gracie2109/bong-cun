<template>
  <div class="flex items-stretch">
    <TooltipProvider>
      <template v-for="(item, index) in props.type" :key="index">
        <Tooltip v-if="item.isShow">
          <TooltipTrigger as-child>
            <Button variant="ghost" @click="handleClick(item)">
              <component :is="getIcon(item.id)" />
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            <p>{{ item.id }}</p>
          </TooltipContent>
        </Tooltip>
      </template>
      <slot></slot>
    </TooltipProvider>
  </div>
</template>

<script setup lang="ts">
import { defineProps, computed, toRaw, h } from "vue";
import { Button } from "@/components/ui/button";
import { Trash, Edit } from "lucide-vue-next";
import type { Row } from "@tanstack/vue-table";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import type { T_ROW_FUNCTION } from "@/types";
const emits = defineEmits(["click"]);
const props = defineProps<{
  row: Row<any>;
  type: T_ROW_FUNCTION[];
}>();

const getIcon = (id: T_ROW_FUNCTION["id"]) => {
  switch (id) {
    case "DELETE":
      return h(Trash, { class: " text-red-600" });
    case "EDIT":
      return h(Edit, { class: "text-green-600" });
    default:
      return null; // Or a default icon
  }
};

function handleClick(item: any) {
  emits("click", { action: toRaw(item), row: toRaw(props.row.original) });
}
</script>
