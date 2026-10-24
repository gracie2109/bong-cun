<template>
  <DropdownMenu>
    <DropdownMenuTrigger as-child>
      <button
        type="button"
        class="dashboard-no-drag flex size-11 items-center justify-center rounded-lg bg-white/90 text-muted-foreground shadow ring-1 ring-border hover:text-foreground"
        :aria-label="$t('dashboard.layout.itemMenu')"
      >
        <MoreHorizontal class="size-5" />
      </button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="end" class="w-44">
      <DropdownMenuItem v-if="configurable" @select="emit('settings')">
        <Settings2 class="mr-2 size-4" />{{ $t("dashboard.layout.settings") }}
      </DropdownMenuItem>
      <DropdownMenuItem @select="emit('move', -1)"><ArrowUp class="mr-2 size-4" />{{ $t("dashboard.layout.moveUp") }}</DropdownMenuItem>
      <DropdownMenuItem @select="emit('move', 1)"><ArrowDown class="mr-2 size-4" />{{ $t("dashboard.layout.moveDown") }}</DropdownMenuItem>
      <DropdownMenuSeparator />
      <DropdownMenuItem v-for="preset in presets" :key="preset" @select="emit('resize', preset)">
        <Maximize2 class="mr-2 size-4" />{{ $t(`dashboard.layout.size.${preset}`) }}
      </DropdownMenuItem>
      <DropdownMenuSeparator />
      <DropdownMenuItem class="text-red-600 focus:text-red-600" @select="emit('remove')">
        <Trash2 class="mr-2 size-4" />{{ $t("dashboard.layout.remove") }}
      </DropdownMenuItem>
    </DropdownMenuContent>
  </DropdownMenu>
</template>

<script lang="ts" setup>
import { ArrowDown, ArrowUp, Maximize2, MoreHorizontal, Settings2, Trash2 } from "lucide-vue-next";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type { SizePreset } from "./useItemActions";

const presets: SizePreset[] = ["small", "medium", "large"];
defineProps<{ configurable?: boolean }>();
const emit = defineEmits<{ move: [step: -1 | 1]; resize: [preset: SizePreset]; remove: []; settings: [] }>();
</script>
