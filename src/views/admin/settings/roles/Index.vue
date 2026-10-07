<template>
  <RbacLayout>
    <template #actions>
      <Button @click="startNew">
        <Plus class="mr-2 size-4" />
        {{ $t("rbac.roles.add") }}
      </Button>
    </template>

    <div class="grid items-start gap-5 lg:grid-cols-[300px_minmax(0,1fr)]">
      <aside class="overflow-hidden rounded-xl border bg-white lg:sticky lg:top-4">
        <div class="border-b bg-muted/40 px-4 py-3 text-sm font-semibold">
          {{ $t("rbac.roles.list", { n: roles.length }) }}
        </div>
        <div v-if="rolesQuery.isPending.value" class="space-y-2 p-3">
          <Skeleton v-for="i in 4" :key="i" class="h-14 w-full" />
        </div>
        <ul v-else class="divide-y">
          <li v-if="creating">
            <div class="border-l-4 border-primary bg-primary/5 px-4 py-3">
              <p class="font-semibold text-primary">{{ $t("rbac.roles.new") }}</p>
            </div>
          </li>
          <li v-for="role in roles" :key="role.id">
            <button
              type="button"
              class="w-full border-l-4 px-4 py-3 text-left transition-colors"
              :class="!creating && selected?.id === role.id ? 'border-primary bg-primary/5' : 'border-transparent hover:bg-muted/40'"
              @click="select(role.id)"
            >
              <span class="flex items-center gap-2">
                <span class="font-semibold" :class="!creating && selected?.id === role.id ? 'text-primary' : ''">
                  {{ role.description || role.name }}
                </span>
                <span
                  v-if="role.isSystem"
                  class="rounded-full bg-muted px-1.5 py-0.5 text-[10px] font-semibold uppercase text-muted-foreground"
                >
                  {{ $t("rbac.system") }}
                </span>
              </span>
              <span class="mt-0.5 flex items-center gap-2 text-xs text-muted-foreground">
                <span class="font-mono">{{ role.name }}</span>
                <span>·</span>
                <span>{{ $t("rbac.roles.staffCount", { n: role.staffCount }) }}</span>
                <span>·</span>
                <span>{{ $t("rbac.roles.grantCount", { n: role.permissions.length }) }}</span>
              </span>
            </button>
          </li>
        </ul>
      </aside>

      <RoleEditor
        v-if="creating || selected"
        :role="creating ? null : selected"
        :roles="roles"
        :permissions="permissions"
        :staff="staff"
        :branches="branches"
        @saved="onSaved"
        @deleted="onDeleted"
      />
      <div v-else class="rounded-xl border bg-white px-4 py-16 text-center text-sm text-muted-foreground">
        {{ $t("rbac.roles.empty") }}
      </div>
    </div>
  </RbacLayout>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { Plus } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { useBranches } from "@/queries/branches";
import { usePermissionsList } from "@/queries/permissions";
import { useRolesList } from "@/queries/roles";
import { useStaffList } from "@/queries/staff";
import RbacLayout from "../RbacLayout.vue";
import RoleEditor from "./RoleEditor.vue";

const route = useRoute();
const router = useRouter();

const rolesQuery = useRolesList();
const roles = computed(() => rolesQuery.data.value ?? []);
const permissionsQuery = usePermissionsList();
const permissions = computed(() => permissionsQuery.data.value ?? []);
const staffQuery = useStaffList();
const staff = computed(() => staffQuery.data.value ?? []);
const branchesQuery = useBranches();
const branches = computed(() => branchesQuery.data.value ?? []);

const creating = ref(false);
// The selected role lives in the URL (?role=cashier) so the matrix can link straight to it.
const selectedId = computed(() => (typeof route.query.role === "string" ? route.query.role : null));
const selected = computed(
  () => roles.value.find((role) => role.id === selectedId.value) ?? roles.value[0] ?? null
);

const select = (id: string) => {
  creating.value = false;
  router.replace({ query: { ...route.query, role: id } });
};

const startNew = () => {
  creating.value = true;
};

const onSaved = (name: string) => select(name);

const onDeleted = () => {
  creating.value = false;
  router.replace({ query: { ...route.query, role: undefined } });
};

watch(selectedId, (id) => {
  if (id) creating.value = false;
});
</script>
