<template>
  <Avatar :class="cn('ring-1 ring-border', props.class)">
    <AvatarImage v-if="photoUrl" :src="photoUrl" :alt="name" loading="lazy" />
    <AvatarFallback class="bg-primary/15 font-semibold text-primary">
      <Icon v-if="speciesIcon" :icon="speciesIcon" class="size-1/2" />
      <template v-else>{{ initialsOf(name) }}</template>
    </AvatarFallback>
  </Avatar>
</template>

<script lang="ts" setup>
import type { HTMLAttributes } from "vue";
import { Icon } from "@iconify/vue";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { cn } from "@/lib/utils";
import { initialsOf } from "@/lib/initials";

// A pet's round photo. Without one it shows the species icon, or the first letters of the name.
// Size comes from `class` (for example "size-10").
const props = defineProps<{
  name: string;
  photoUrl?: string | null;
  speciesIcon?: string | null;
  class?: HTMLAttributes["class"];
}>();
</script>
