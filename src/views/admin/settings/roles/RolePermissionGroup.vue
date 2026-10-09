<template>
  <Collapsible
    :open="open"
    class="overflow-hidden rounded-xl border"
    @update:open="(value: boolean) => emit('update:open', value)"
  >
    <div class="flex items-center gap-3 bg-muted/30 px-4 py-3">
      <CollapsibleTrigger as-child>
        <button type="button" class="flex min-w-0 flex-1 items-center gap-3 text-left">
          <ChevronDown
            class="size-4 shrink-0 text-muted-foreground transition-transform"
            :class="open ? '' : '-rotate-90'"
          />
          <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
            <Icon :icon="moduleIcon(group.module)" class="size-4" />
          </span>
          <span class="truncate font-semibold">{{ group.module ?? $t("rbac.ungrouped") }}</span>
          <span
            class="shrink-0 rounded-full px-2 py-0.5 text-[11px] font-semibold"
            :class="state === true ? 'bg-emerald-50 text-emerald-700' : 'bg-muted text-muted-foreground'"
          >
            {{ $t("rbac.roles.moduleCount", { n: granted, total: group.items.length }) }}
          </span>
        </button>
      </CollapsibleTrigger>
      <label class="flex shrink-0 items-center gap-2 text-xs font-medium text-muted-foreground">
        {{ state === "indeterminate" ? $t("rbac.roles.partial") : $t("rbac.roles.selectAll") }}
        <Checkbox
          :checked="state"
          :disabled="locked"
          @update:checked="(value: boolean | 'indeterminate') => emit('setGroup', group.items, value === true)"
        />
      </label>
    </div>

    <CollapsibleContent>
      <div class="grid gap-3 p-4 md:grid-cols-2">
        <div
          v-for="permission in group.items"
          :key="permission.id"
          class="flex gap-3 rounded-lg border p-3 transition-colors"
          :class="rowState(grants, permission, isSuperAdmin) === false ? 'bg-white' : 'border-primary/30 bg-primary/5'"
        >
          <Checkbox
            class="mt-0.5"
            :checked="rowState(grants, permission, isSuperAdmin)"
            :disabled="locked"
            :aria-label="permission.description || permission.name"
            @update:checked="(value: boolean | 'indeterminate') => emit('setRow', permission, value === true)"
          />
          <div class="min-w-0 flex-1 space-y-2">
            <div>
              <p class="text-sm font-semibold leading-snug">{{ permission.description || permission.name }}</p>
              <p class="font-mono text-[11px] text-muted-foreground">{{ permission.name }}</p>
            </div>
            <div class="flex flex-wrap gap-1">
              <button
                v-for="method in methodsOf(permission)"
                :key="method"
                type="button"
                :aria-pressed="isOn(permission.id, method)"
                :disabled="locked"
                class="flex items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] font-medium transition-colors disabled:cursor-not-allowed"
                :class="isOn(permission.id, method)
                  ? 'border-primary bg-primary text-primary-foreground'
                  : 'border-dashed text-muted-foreground hover:border-primary hover:text-primary'"
                @click="emit('setCell', permission.id, method, !has(permission.id, method))"
              >
                <Icon :icon="METHOD_ICONS[method]" class="size-3" />
                {{ $t(`rbac.methods.${method}`) }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </CollapsibleContent>
  </Collapsible>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Icon } from "@iconify/vue";
import { ChevronDown } from "lucide-vue-next";
import { Checkbox } from "@/components/ui/checkbox";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import type { Permission } from "@/repositories/permissions";
import { METHOD_ICONS, methodsOf, moduleIcon, type Method } from "../rbac";
import { groupGranted, groupState, rowState, type Grants } from "./roleGrants";
import type { KeyedPermissionGroup } from "./usePermissionGroups";

const props = defineProps<{
  group: KeyedPermissionGroup;
  open: boolean;
  grants: Grants;
  isSuperAdmin: boolean;
  /** Nobody can edit: a superAdmin role, or a viewer without the manage permission. */
  locked: boolean;
}>();

const emit = defineEmits<{
  "update:open": [open: boolean];
  setGroup: [items: Permission[], on: boolean];
  setRow: [permission: Permission, on: boolean];
  setCell: [permissionId: string, method: Method, on: boolean];
}>();

const state = computed(() => groupState(props.grants, props.group.items, props.isSuperAdmin));
const granted = computed(() => groupGranted(props.grants, props.group.items, props.isSuperAdmin));

const has = (permissionId: string, method: Method): boolean =>
  props.grants[permissionId]?.includes(method) ?? false;

const isOn = (permissionId: string, method: Method): boolean => props.isSuperAdmin || has(permissionId, method);
</script>
