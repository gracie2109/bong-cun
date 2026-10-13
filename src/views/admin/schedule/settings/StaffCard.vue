<template>
  <section class="rounded-xl border bg-white">
    <header class="border-b px-4 py-3">
      <h2 class="font-semibold">{{ $t("spa.settings.staff") }}</h2>
      <p class="text-xs text-muted-foreground">{{ $t("spa.settings.staffHint") }}</p>
    </header>

    <ul class="divide-y">
      <li v-if="!staff.length" class="px-4 py-6 text-center text-sm text-muted-foreground">
        {{ $t("spa.settings.noStaff") }}
      </li>
      <li v-for="member in staff" :key="member.userId" class="flex items-center justify-between gap-3 px-4 py-2.5">
        <div class="min-w-0">
          <p class="truncate text-sm font-medium">{{ member.name }}</p>
          <p class="text-xs text-muted-foreground">{{ member.role }}</p>
        </div>
        <Switch
          :model-value="member.doesServices"
          :disabled="!canEdit || mutation.isPending.value"
          :aria-label="$t('spa.settings.doesServices')"
          @update:model-value="(value: boolean) => toggle(member.userId, value)"
        />
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Switch } from "@/components/ui/switch";
import { useBranchStaff, useSetStaffDoesServices } from "@/queries/spa";

const props = defineProps<{ branchId: string | undefined; canEdit: boolean }>();

const query = useBranchStaff(computed(() => props.branchId));
const staff = computed(() => query.data.value ?? []);
const mutation = useSetStaffDoesServices();

const toggle = (userId: string, value: boolean) => {
  if (props.branchId) mutation.mutate({ userId, branchId: props.branchId, value });
};
</script>
