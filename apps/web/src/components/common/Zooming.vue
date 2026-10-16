<template>
  <VueZoomable
    class="h-full w-full"
    selector="#myContent"
    :minZoom="1"
    :maxZoom="3"
    :enableControlButton="false"
  >
    <img
      :src="props.image"
      id="myContent"
      class="w-full h-full object-contain"
    />
  </VueZoomable>
</template>

<script lang="ts" setup>
import VueZoomable from "vue-zoomable";
import "vue-zoomable/dist/style.css";

const props = withDefaults(
  defineProps<{
    image: string;
    showControl: boolean;
  }>(),
  {
    showControl: true,
  }
);
</script>
