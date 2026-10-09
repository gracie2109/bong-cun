<template>
  <AppDialog
    :open="openSettingView"
    :title="$t('common.settingView')"
    size="sm"
    hide-footer
    @update:open="$emit('changeOpenSettingView')"
  >
    <div class="grid gap-4">
      <div v-for="(i, j) in columns" :key="j" class="flex gap-3 items-center">
        <Checkbox
          :id="i.id"
          :checked="i.getIsVisible()"
          @update:checked="(value) => i.toggleVisibility(!!value)"
        />
        <label :for="i.id" class="cursor-pointer capitalize">{{ i.id }}</label>
      </div>
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import { Checkbox } from "@/components/ui/checkbox";
import AppDialog from "@/components/common/AppDialog.vue";
import { LOCAL_STORAGE_KEY } from "@/lib/constants";
import type { Table } from "@tanstack/vue-table";
import { computed, ref, watch } from "vue";

const props = defineProps<{
  table: Table<any>;
  openSettingView: boolean;
  saveColumnVisible: {
    name: string;
    isRemeber: boolean;
  };
}>();

const emits = defineEmits(["changeOpenSettingView"]);

const columns = computed(() => {
  return props.table.getAllColumns().filter((column) => {
    return typeof column.accessorFn !== "undefined" && column.getCanHide();
  });
});

function saveColumnSetting() {
  if (props.saveColumnVisible.isRemeber) {
    const visibleColumns = props.table.getVisibleLeafColumns();
    const resLocal = localStorage.getItem(
      LOCAL_STORAGE_KEY.VISIBLE_COLUMN
    ) as any;

    const parseData = resLocal ? JSON.parse(resLocal) : null;

    if (parseData) {
      const res = {
        ...parseData,
        [props.saveColumnVisible.name]: visibleColumns.map((i) => i.id),
      };
      localStorage.setItem(
        LOCAL_STORAGE_KEY.VISIBLE_COLUMN,
        JSON.stringify(res)
      );
    } else {
      const res = {
        [props.saveColumnVisible.name]: visibleColumns.map((i) => i.id),
      };
      localStorage.setItem(
        LOCAL_STORAGE_KEY.VISIBLE_COLUMN,
        JSON.stringify(res)
      );
    }
  }
}

watch(
  () => props.table.getVisibleLeafColumns(),
  () => {
    if (props.saveColumnVisible?.isRemeber) {
      saveColumnSetting();
    }
  }
);
</script>
