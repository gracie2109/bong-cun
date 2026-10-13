<template>
  <section class="rounded-xl border bg-white">
    <header class="flex items-center justify-between gap-3 border-b px-4 py-3">
      <div>
        <h2 class="font-semibold">{{ $t("spa.settings.tables") }}</h2>
        <p class="text-xs text-muted-foreground">{{ $t("spa.settings.tablesHint") }}</p>
      </div>
      <Button v-if="canEdit" size="sm" @click="openNew">
        <Plus class="mr-1 size-4" />
        {{ $t("spa.settings.addTable") }}
      </Button>
    </header>

    <ul class="divide-y">
      <li v-if="!resources.length" class="px-4 py-6 text-center text-sm text-muted-foreground">
        {{ $t("spa.settings.noTables") }}
      </li>
      <li v-for="item in resources" :key="item.id" class="flex items-center justify-between gap-3 px-4 py-2.5">
        <span class="text-sm font-medium" :class="!item.isActive && 'text-muted-foreground line-through'">{{ item.name }}</span>
        <div class="flex items-center gap-2">
          <Switch
            :model-value="item.isActive"
            :disabled="!canEdit || mutation.isPending.value"
            :aria-label="$t('spa.settings.active')"
            @update:model-value="(value: boolean) => toggle(item, value)"
          />
          <Button v-if="canEdit" size="sm" variant="ghost" @click="openEdit(item)">
            <Pencil class="size-4" />
          </Button>
        </div>
      </li>
    </ul>

    <AppDialog
      :open="dialogOpen"
      :title="editing ? $t('spa.settings.editTable') : $t('spa.settings.addTable')"
      :ok-text="$t('petCare.common.save')"
      :ok-disabled="!name.trim()"
      :busy="mutation.isPending.value"
      form-id="spa-table-form"
      size="sm"
      @update:open="dialogOpen = $event"
    >
      <form id="spa-table-form" class="space-y-2" @submit.prevent="submit">
        <Label for="spa-table-name">{{ $t("spa.settings.tableName") }}</Label>
        <Input id="spa-table-name" v-model="name" :placeholder="$t('spa.settings.tableNamePlaceholder')" />
      </form>
    </AppDialog>
  </section>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Pencil, Plus } from "lucide-vue-next";
import AppDialog from "@/components/common/AppDialog.vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { useSaveSpaResource, useSpaResources } from "@/queries/spa";
import type { SpaResource } from "@/repositories/spa";

const props = defineProps<{ branchId: string | undefined; canEdit: boolean }>();

const query = useSpaResources(computed(() => props.branchId));
const resources = computed(() => query.data.value ?? []);
const mutation = useSaveSpaResource();

const dialogOpen = ref(false);
const editing = ref<SpaResource | null>(null);
const name = ref("");

const openNew = () => {
  editing.value = null;
  name.value = "";
  dialogOpen.value = true;
};

const openEdit = (item: SpaResource) => {
  editing.value = item;
  name.value = item.name;
  dialogOpen.value = true;
};

const submit = async () => {
  if (!props.branchId || !name.value.trim()) return;
  try {
    await mutation.mutateAsync({
      input: { branchId: props.branchId, name: name.value.trim() },
      id: editing.value?.id,
    });
    dialogOpen.value = false;
  } catch {
    // the mutation already showed the failure toast
  }
};

// Tables are archived, not deleted: past appointments keep pointing at them.
const toggle = (item: SpaResource, isActive: boolean) =>
  mutation.mutate({ input: { branchId: item.branchId, name: item.name, isActive }, id: item.id });
</script>
