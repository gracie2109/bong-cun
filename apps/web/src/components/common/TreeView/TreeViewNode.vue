<template>
  <div :class="classes" class="treeview-node treeview-node--click">
    <div class="treeview-node__root">
      <template v-if="props.item">
      
        <div class="treeview-node__content">
          <div
            class="treeview-node__level"
            v-for="l in numberOfLevels"
            :key="l"
          />
          <Icon v-if="hasChildren" :icon="hasChildren && !isOpen ? 'lucide:chevron-right' :'lucide:chevron-down'" />
          <div @click.stop="openNode" v-if="hasChildren">
          
            <Icon
              :class="{
                open: isOpen,
                close: !isOpen,
              }"
              :icon="
                props.item.icon ||
                (isOpen ? 'lucide:folder-open' : 'lucide:folder')
              "
              class="w-[15px] h-[15px] treeview-node__toggle"
            />
          </div>

          <div class="treeview-node__level" v-else />
          
          <Icon
            v-if="!hasChildren"
            :class="{
              open: isOpen,
              close: !isOpen,
            }"
            :icon="props.item.icon || 'lucide:file'"
            class="w-[15px] h-[15px] treeview-node__toggle"
          />
          <template v-if="props.selectable">
            <div class="radio-group" v-if="props.radio">
              <input
                v-if="props.showBox"
                :disabled="props.disabled"
                class="radio"
                @click="nodeSelected"
                type="radio"
                :checked="isChecked"
              />
              <span @click="nodeSelected">
                {{ item.name }}
              </span>
            </div>
            <template v-else>
              <label @click="nodeSelected">
                <Checkbox
                  v-if="props.showBox"
                  :disabled="props.disabled"
                  :checked="isIndeterminate ? 'indeterminate' : isChecked"
                  class="w-4 h-4 mr-2"
                  @click="nodeSelected"
                />
                <span @click="nodeSelected">
                  {{ item.name }}
                </span>
              </label>
            </template>
          </template>
          <template v-else> {{ item.name }} </template>
        </div>
      </template>
    </div>
    <div class="treeview-node__children" v-if="isOpen">
      <tree-view-node
        v-for="child in props.item.children"
        :selectable="props.selectable"
        :level="props.level + 1"
        :key="child.id"
        :item="child"
        :color="props.color"
        :disabled="props.disabled"
        :unopenable="props.unopenable"
        :identifier="props.identifier"
        :radio="props.radio"
        @change="childNodeChanged"
      />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { useEventBus } from "@vueuse/core";
import { computed, inject } from "vue";
import { checkChildSelectStatus } from "./helpers";
import type { TreeViewNodeItem } from "./models";
import { Icon } from "@iconify/vue";
import { Checkbox } from "@/components/ui/checkbox";

const emit = defineEmits<{
  (e: "change"): void;
}>();

const selectedNodes = inject<Set<number>>("selected-nodes");
const openedNodes = inject<Set<number>>("opened-nodes");

const props = defineProps<{
  level: number;
  item: TreeViewNodeItem;
  selectable?: boolean;
  radio?: boolean;
  disabled?: boolean;
  unopenable?: boolean;
  color?: string;
  identifier: number;
  showBox?: boolean;
}>();

const { emit: emitNodeOpen } = useEventBus<number>(
  `open-node-${props.identifier}`
);
const { emit: emitNodeSelected } = useEventBus<TreeViewNodeItem>(
  `select-node-${props.identifier}`
);

const classes = computed(() => ({
  "treeview-node--leaf": !hasChildren.value,
}));

const isOpen = computed(() => openedNodes?.has(props.item.id));

const isSelected = computed(() => selectedNodes?.has(props.item.id));

const hasChildren = computed(
  () => !!props.item?.children && !!props.item?.children?.length
);

const allChildrenSelected = computed(() =>
  checkChildSelectStatus(selectedNodes!, props.item, "all")
);

const atLeastOneChildSelected = computed(() =>
  checkChildSelectStatus(selectedNodes!, props.item, "atLeastOne")
);

const isChecked = computed(() => {
  if (hasChildren.value) {
    if (allChildrenSelected.value) return true;
    if (atLeastOneChildSelected.value) return false;
    return false;
  }
  return isSelected.value;
});

const isIndeterminate = computed(() => {
  if (hasChildren.value) {
    if (allChildrenSelected.value) return false;
    if (atLeastOneChildSelected.value) return true;
  }
  return false;
});

const numberOfLevels = computed(() => {
  if (hasChildren.value || props.level !== 1) return props.level - 1;
  return 0;
});

const childNodeChanged = () => {
  const id = props.item.id;
  if (hasChildren.value) {
    if (allChildrenSelected.value) {
      if (!isSelected.value) nodeSelected();
    } else {
      if (atLeastOneChildSelected.value) {
        if (!isSelected.value) selectedNodes!.add(id);
      } else {
        if (isSelected.value) nodeSelected();
      }
    }
    emit("change");
  }
};

const nodeSelected = () => {
  emitNodeSelected(props.item);
  emit("change");
};

const openNode = () => {
  if (hasChildren.value && !props.unopenable) emitNodeOpen(props.item.id);
};
</script>

<style scoped>
.radio-group {
  display: flex;
  align-items: center;
  justify-items: center;
  justify-content: center;
  gap: 5px;
}

input[type="radio"] {
  margin: 0;
}
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
