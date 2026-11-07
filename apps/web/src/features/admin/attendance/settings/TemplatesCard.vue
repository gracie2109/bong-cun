<template>
  <section class="rounded-xl border bg-white">
    <header class="flex flex-wrap items-center justify-between gap-3 border-b px-4 py-3">
      <div>
        <h2 class="font-semibold">{{ $t("attendance.templates.title") }}</h2>
        <p class="text-xs text-muted-foreground">{{ $t("attendance.templates.hint") }}</p>
      </div>
      <div class="flex items-center gap-3">
        <label class="flex items-center gap-2 text-sm text-muted-foreground">
          <Switch v-model:checked="showInactive" />
          {{ $t("attendance.templates.showInactive") }}
        </label>
        <Button v-if="canEdit" size="sm" @click="openNew">
          <Plus class="mr-1 size-4" />
          {{ $t("attendance.templates.add") }}
        </Button>
      </div>
    </header>

    <ul v-if="templates.length" class="divide-y">
      <TemplateRow v-for="item in templates" :key="item.id" :template="item" :can-edit="canEdit" @edit="openEdit(item)" @toggle="toggle(item)" />
    </ul>
    <p v-else class="px-4 py-8 text-center text-sm text-muted-foreground">
      {{ query.isPending.value ? $t("petCare.common.loading") : $t("attendance.templates.empty") }}
    </p>

    <TemplateDialog v-model:open="dialogOpen" :branch-id="branchId" :template="editing" />
    <ConfirmReasonDialog :confirm="confirm" />
  </section>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Plus } from "lucide-vue-next";
import { useI18n } from "vue-i18n";
import ConfirmReasonDialog from "@/components/common/ConfirmReasonDialog.vue";
import { useConfirmAction } from "@/components/common/useConfirmAction";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { useSetShiftTemplateActive, useShiftTemplates } from "@/features/admin/attendance/queries";
import type { ShiftTemplate } from "@bongcun/core/attendance";
import TemplateDialog from "./TemplateDialog.vue";
import TemplateRow from "./TemplateRow.vue";

const props = defineProps<{ branchId: string | undefined; canEdit: boolean }>();

const showInactive = ref(false);
const query = useShiftTemplates(computed(() => props.branchId), showInactive);
const templates = computed(() => query.data.value ?? []);
const activeMutation = useSetShiftTemplateActive();

const dialogOpen = ref(false);
const editing = ref<ShiftTemplate | null>(null);

const openNew = () => {
  editing.value = null;
  dialogOpen.value = true;
};
const openEdit = (item: ShiftTemplate) => {
  editing.value = item;
  dialogOpen.value = true;
};
const { t } = useI18n();
const confirm = useConfirmAction();
const toggle = async (item: ShiftTemplate) => {
  const key = item.isActive ? "archiveTemplate" : "restoreTemplate";
  const answer = await confirm.ask({
    title: t(`attendance.confirm.${key}.title`),
    message: t(`attendance.confirm.${key}.message`, { name: item.name }),
    danger: item.isActive,
  });
  if (answer.ok) activeMutation.mutate({ id: item.id, active: !item.isActive });
};
</script>
