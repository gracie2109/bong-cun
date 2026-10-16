<template>
  <div>
    <TreeView
      color="blue"
      :items="treeViewItems"
      v-model="treeViewSelection"
      :showBox="false"
    />
  </div>
</template>

<script lang="ts" setup>
import TreeView from "@/components/common/TreeView/Index.vue";
import { ref } from "vue";

const treeViewSelection = ref([]);

const treeViewItems = ref([
  {
    id: 1,
    name: "Nhosm nguoiwf dufn",
    children: [
      {
        id: 5,
        name: "ID 5",
        children: [
          {
            id: 6,
            name: "ID 6",
            children: [
              {
                id: 7,
                name: "ID 7",
                children: [
                  { id: 8, name: "ID 8" },
                  { id: 9, name: "ID 9" },
                ],
              },
            ],
          },
          {
            id: 10,
            name: "ID 10",
            children: [
              {
                id: 11,
                name: "ID 11",
                children: [
                  { id: 12, name: "ID 12" },
                  { id: 13, name: "ID 13" },
                  { id: 14, name: "ID 14" },
                ],
              },
            ],
          },
        ],
      },
    ],
  },
]);
</script>
