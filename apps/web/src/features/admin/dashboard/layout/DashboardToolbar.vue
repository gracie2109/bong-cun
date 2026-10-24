<template>
  <div class="flex flex-wrap items-center gap-2">
    <template v-if="!editing">
      <Button v-if="canEdit" variant="outline" size="sm" @click="emit('start')">
        <LayoutGrid class="mr-1.5 size-4" />{{ $t("dashboard.layout.customize") }}
      </Button>
    </template>
    <template v-else>
      <Button variant="outline" size="sm" :disabled="saving || !canAdd" :title="canAdd ? undefined : $t('dashboard.add.full')" @click="emit('add')">
        <Plus class="mr-1.5 size-4" />{{ $t("dashboard.add.button") }}
      </Button>
      <span v-if="isDirty" class="text-xs text-amber-600">{{ $t("dashboard.layout.unsaved") }}</span>
      <Button variant="ghost" size="sm" :disabled="saving" @click="askReset = true">
        <RotateCcw class="mr-1.5 size-4" />{{ $t("dashboard.layout.reset") }}
      </Button>
      <Button variant="outline" size="sm" :disabled="saving" @click="onCancel">{{ $t("common.cancel") }}</Button>
      <Button size="sm" :disabled="saving || !isDirty" @click="emit('save')">
        <Save class="mr-1.5 size-4" />{{ $t("dashboard.layout.save") }}
      </Button>
    </template>
    <span v-if="!editing && savedAt" class="text-xs text-muted-foreground">{{ $t("dashboard.layout.savedAt", { time: savedAt }) }}</span>

    <ConfirmDialog
      :open="askReset"
      :title="$t('dashboard.layout.resetAsk')"
      :desc="$t('dashboard.layout.resetDesc')"
      :ok-btn="$t('dashboard.layout.reset')"
      danger
      @open-change="askReset = false"
      @handle-ok="emit('reset')"
    />
    <ConfirmDialog
      :open="askCancel"
      :title="$t('dashboard.layout.discardAsk')"
      :ok-btn="$t('dashboard.layout.discard')"
      danger
      @open-change="askCancel = false"
      @handle-ok="emit('cancel')"
    />
  </div>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { LayoutGrid, Plus, RotateCcw, Save } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";

const props = defineProps<{
  editing: boolean;
  isDirty: boolean;
  saving: boolean;
  canEdit: boolean;
  /** False once the dashboard holds the most widgets it may. */
  canAdd: boolean;
  /** Already formatted time of the last save, or empty. */
  savedAt?: string;
}>();
const emit = defineEmits<{ start: []; save: []; cancel: []; reset: []; add: [] }>();

const askReset = ref(false);
const askCancel = ref(false);
// Cancelling with changes asks first; without changes it just leaves edit mode.
const onCancel = () => (props.isDirty ? (askCancel.value = true) : emit("cancel"));
</script>
