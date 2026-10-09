<template>
  <Transition
    enter-from-class="translate-y-4 opacity-0"
    leave-to-class="translate-y-4 opacity-0"
    enter-active-class="transition duration-200"
    leave-active-class="transition duration-150"
  >
    <div
      v-if="visible"
      class="sticky bottom-4 z-20 flex flex-wrap items-center justify-between gap-3 rounded-xl border bg-white px-4 py-3 shadow-lg"
    >
      <p class="flex items-center gap-2 text-sm">
        <span class="flex size-8 items-center justify-center rounded-lg bg-amber-50 text-amber-600">
          <ClipboardPen class="size-4" />
        </span>
        <b>{{ $t("rbac.roles.unsavedCount", { n: changeCount }) }}</b>
        <span class="text-muted-foreground">{{ $t("rbac.roles.unsavedOn", { name: roleLabel }) }}</span>
      </p>
      <div class="flex gap-2">
        <Button type="button" variant="ghost" :disabled="pending" @click="emit('discard')">
          {{ $t("rbac.roles.discard") }}
        </Button>
        <Button type="button" :disabled="pending" @click="emit('save')">
          <Check class="mr-2 size-4" />
          {{ $t("rbac.roles.savePermissions") }}
        </Button>
      </div>
    </div>
  </Transition>
</template>

<script lang="ts" setup>
import { Check, ClipboardPen } from "lucide-vue-next";
import { Button } from "@/components/ui/button";

defineProps<{
  visible: boolean;
  changeCount: number;
  roleLabel: string;
  pending: boolean;
}>();

const emit = defineEmits<{ discard: []; save: [] }>();
</script>
