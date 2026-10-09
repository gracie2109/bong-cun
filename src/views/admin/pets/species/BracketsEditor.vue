<template>
  <div class="space-y-4">
    <div>
      <h3 class="font-semibold">{{ $t("petCare.species.bracketsTitle") }}</h3>
      <p class="text-sm text-muted-foreground">{{ $t("petCare.species.bracketsHint") }}</p>
    </div>

    <Skeleton v-if="isPending" class="h-40 w-full" />
    <template v-else>
      <BracketRuler v-if="segments.length" :segments="segments" />

      <BracketRowsTable :rows="rows" :can-update="canUpdate" @remove="removeRow" />

      <BracketIssues v-if="issueTexts.length" :issues="issueTexts" />
      <p v-if="removedCount > 0" class="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
        {{ $t("petCare.species.removeWarning", { n: removedCount }) }}
      </p>

      <div v-if="canUpdate" class="flex flex-wrap items-center justify-between gap-2">
        <Button type="button" variant="outline" @click="addRow">
          <Plus class="mr-2 size-4" />
          {{ $t("petCare.species.addBracket") }}
        </Button>
        <div class="flex gap-2">
          <Button type="button" variant="ghost" :disabled="!dirty" @click="resetRows">
            {{ $t("petCare.species.resetBrackets") }}
          </Button>
          <Button type="button" :disabled="!canSave" @click="requestSave">
            {{ $t("petCare.species.saveBrackets") }}
          </Button>
        </div>
      </div>
    </template>

    <ConfirmDialog
      :open="confirmOpen"
      :title="$t('petCare.species.confirmSaveTitle', { n: removedCount })"
      :desc="$t('petCare.species.confirmSaveDesc')"
      :ok-btn="$t('petCare.common.confirm')"
      @cancel="confirmOpen = false"
      @open-change="confirmOpen = false"
      @handle-ok="save"
    />
  </div>
</template>

<script lang="ts" setup>
import { Plus } from "lucide-vue-next";
import ConfirmDialog from "@/components/common/ConfirmDialog.vue";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { usePermission } from "@/composables/usePermission";
import BracketIssues from "./BracketIssues.vue";
import BracketRowsTable from "./BracketRowsTable.vue";
import BracketRuler from "./BracketRuler.vue";
import { useBracketRows } from "./useBracketRows";

const props = defineProps<{ speciesId: string }>();

const { canUpdate } = usePermission("petServices");

const {
  isPending,
  rows,
  confirmOpen,
  issueTexts,
  removedCount,
  dirty,
  canSave,
  segments,
  addRow,
  removeRow,
  resetRows,
  requestSave,
  save,
} = useBracketRows(() => props.speciesId);
</script>
