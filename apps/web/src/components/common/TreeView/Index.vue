<template>
  <div class="treeview" :class="classes">
    <tree-view-node
      v-for="item in props.items"
      :selectable="props.selectable"
      :color="props.color"
      :level="1"
      :item="item"
      :key="item.id"
      :disabled="props.disabled"
      :unopenable="props.unopenable"
      :radio="props.radio"
      :identifier="identifier"
      :showBox="props.showBox"
    />
  </div>
</template>

<script lang="ts" setup>
import { rand, useEventBus } from "@vueuse/core";
import {
  computed,
  onMounted,
  onUnmounted,
  provide,
  reactive,
  watch,
} from "vue";
import {
  applyToAllChildren,
  checkChildSelectStatus,
  gatherAllNodeIds,
} from "./helpers";
import type { TreeViewNodeItem, TreeViewSelectionMode } from "./models";
import treeViewNode from "./TreeViewNode.vue";

const emit = defineEmits<{
  (e: "update:modelValue", values: number[]): void;
}>();

const props = withDefaults(
  defineProps<{
    dense?: boolean;
    disabled?: boolean;
    radio?: boolean;
    openAll?: boolean;
    selectable?: boolean;
    unopenable?: boolean;
    color?: string;
    modelValue: number[];
    items: TreeViewNodeItem[];
    selectionMode?: TreeViewSelectionMode;
    showBox?:boolean
  }>(),
  {
    color: "#7e7ec2",
    selectionMode: "leaf",
    selectable: true,
    showBox:true,
    radio: false,
  }
);

const identifier = rand(1, 9999);

const busOpenNode = useEventBus<number>(`open-node-${identifier}`);
const busSelectNode = useEventBus<TreeViewNodeItem>(
  `select-node-${identifier}`
);

const nodeOpened = (id: number) => {
  if (state.openedNodes.has(id)) {
    state.openedNodes.delete(id);
    return;
  }
  state.openedNodes.add(id);
};

const unselectNode = (id: number) => state.selectedNodes.delete(id);

const selectNode = (id: number) => {
  state.selectedNodes.add(id);
};

const toggleNode = (id: number) => {
  if (state.selectedNodes.has(id)) {
    unselectNode(id);
    return;
  }
  selectNode(id);
};

const nodeSelected = (item: TreeViewNodeItem) => {
  if (!!item.children && !!item.children.length) {
    if (
      state.selectedNodes.has(item.id) &&
      checkChildSelectStatus(state.selectedNodes, item, "atLeastOne") &&
      !checkChildSelectStatus(state.selectedNodes, item, "all")
    ) {
      applyToAllChildren(item, selectNode);
    } else {
      toggleNode(item.id);
      applyToAllChildren(
        item,
        state.selectedNodes.has(item.id) ? selectNode : unselectNode
      );
    }
  } else {
    toggleNode(item.id);
  }
};

const unsubscribeOpenNode = busOpenNode.on(nodeOpened);
const unsubscribeSelectNode = busSelectNode.on(nodeSelected);

const state = reactive({
  selectedNodes: new Set<number>(),
  openedNodes: new Set<number>(),
  stopRecursion: false,
});

provide("selected-nodes", state.selectedNodes);
provide("opened-nodes", state.openedNodes);

const classes = computed(() => ({
  "treeview--dense": props.dense,
}));

watch(
  () => state.selectedNodes,
  (val) => {
    emit("update:modelValue", [...val]);
    state.stopRecursion = true;
  },
  {
    deep: true,
  }
);

watch(
  () => props.modelValue,
  (val) => {
    if (state.stopRecursion) {
      state.stopRecursion = false;
      return;
    }
    if (val.length) {
      for (const n of [...new Set(val)]) state.selectedNodes.add(n as number);
      return;
    }
    state.selectedNodes.clear();
  },
  {
    immediate: true,
  }
);

onMounted(() => {
  if (props.openAll === true) {
    let allVals: number[] = [];
    for (const node of props.items) {
      let x = gatherAllNodeIds(node, []);
      allVals = [...allVals, ...x];
    }
    for (const n of [...new Set(allVals)]) state.openedNodes.add(n);
  }
});

onUnmounted(() => {
  unsubscribeOpenNode();
  unsubscribeSelectNode();
});
</script>

<style scoped>
.treeview {
  font-family: Roboto;
}

.treeview-node--click > .treeview-node__root,
.treeview-node--click > .treeview-node__root > .treeview-node__content > * {
  cursor: pointer;
  user-select: none;
}

.treeview-node__root {
  display: flex;
  align-items: center;
  min-height: 48px;
  padding-left: 8px;
  padding-right: 8px;
  position: relative;
}

.treeview-node__root::before {
  background-color: currentColor;
  bottom: 0;
  content: "";
  left: 0;
  opacity: 0;
  pointer-events: none;
  position: absolute;
  right: 0;
  top: 0;
  transition: 0.3s cubic-bezier(0.25, 0.8, 0.5, 1);
}

.treeview-node__root::after {
  content: "";
  font-size: 0;
  min-height: inherit;
}

.treeview-node__children {
  transition: all 0.2s cubic-bezier(0, 0, 0.2, 1);
}

.treeview--dense .treeview-node__root {
  min-height: 40px;
}

.treeview-node__toggle {
  width: 24px;
  user-select: none;
  margin-right: 4px;
}

.treeview-node__level {
  width: 24px;
}

.treeview-node__content {
  align-items: center;
  display: flex;
  flex-basis: 0%;
  flex-grow: 1;
  flex-shrink: 0;
  min-width: 0;
}

</style>
