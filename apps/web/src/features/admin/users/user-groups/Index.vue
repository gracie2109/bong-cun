<template>
  <div id="user_group">
    <GroupTree :treeItems="listGroup" />
  </div>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import GroupTree from "./components/GroupTree.vue";

const listGroup = ref([])
</script>
