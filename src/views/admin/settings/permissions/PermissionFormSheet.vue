<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-lg">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ permission ? $t("rbac.permissions.edit") : $t("rbac.permissions.add") }}</SheetTitle>
        <SheetDescription class="sr-only">{{ $t("rbac.subtitle") }}</SheetDescription>
      </SheetHeader>

      <form id="permission-form" class="flex-1 space-y-5 overflow-y-auto px-6 py-5" @submit.prevent="submit">
        <div class="space-y-2">
          <Label for="permission-code">{{ $t("rbac.permissions.form.code") }}</Label>
          <Input id="permission-code" v-model="code" class="font-mono" autocomplete="off" />
          <p v-if="submitted && !codeValid" class="text-sm text-red-600">{{ $t("rbac.permissions.form.errCode") }}</p>
          <p v-else class="text-xs text-muted-foreground">{{ $t("rbac.permissions.form.codeHint") }}</p>
          <p
            v-if="permission && code.trim() !== permission.name"
            class="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700"
          >
            {{ $t("rbac.permissions.form.renameWarning") }}
          </p>
        </div>

        <div class="space-y-2">
          <Label for="permission-desc">{{ $t("rbac.permissions.form.desc") }}</Label>
          <Textarea id="permission-desc" v-model="description" class="resize-none" rows="2" />
        </div>

        <div class="grid gap-4 sm:grid-cols-[minmax(0,1fr)_120px]">
          <div class="space-y-2">
            <Label for="permission-module">{{ $t("rbac.permissions.form.module") }}</Label>
            <Input
              id="permission-module"
              v-model="module"
              list="permission-modules"
              :placeholder="$t('rbac.permissions.form.modulePlaceholder')"
            />
            <datalist id="permission-modules">
              <option v-for="item in modules" :key="item" :value="item" />
            </datalist>
          </div>
          <div class="space-y-2">
            <Label for="permission-order">{{ $t("rbac.permissions.form.sortOrder") }}</Label>
            <Input id="permission-order" v-model="sortOrder" type="number" step="1" inputmode="numeric" />
          </div>
        </div>

        <div class="space-y-2">
          <Label>{{ $t("rbac.permissions.form.methods") }}</Label>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="method in METHODS"
              :key="method"
              type="button"
              class="flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm transition-colors"
              :class="methods.includes(method) ? 'border-primary bg-primary/10 text-primary' : 'hover:bg-muted'"
              :aria-pressed="methods.includes(method)"
              @click="toggle(method)"
            >
              <Icon :icon="METHOD_ICONS[method]" class="size-4" />
              {{ $t(`rbac.methods.${method}`) }}
            </button>
          </div>
          <p v-if="submitted && methods.length === 0" class="text-sm text-red-600">
            {{ $t("rbac.permissions.form.errMethods") }}
          </p>
        </div>
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button type="button" variant="outline" @click="emit('update:open', false)">
          {{ $t("petCare.common.cancel") }}
        </Button>
        <Button type="submit" form="permission-form" :disabled="pending">
          {{ $t("petCare.common.save") }}
        </Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Icon } from "@iconify/vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Sheet, SheetContent, SheetDescription, SheetFooter, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { Textarea } from "@/components/ui/textarea";
import { useCreatePermission, useUpdatePermission } from "@/queries/permissions";
import type { Permission } from "@/repositories/permissions";
import { METHOD_ICONS, METHODS, methodsOf, PERMISSION_CODE_PATTERN, type Method } from "../rbac";

const props = defineProps<{
  open: boolean;
  permission: Permission | null;
  modules: string[];
}>();

const emit = defineEmits<{ "update:open": [value: boolean] }>();

const createPermission = useCreatePermission();
const updatePermission = useUpdatePermission();
const pending = computed(() => createPermission.isPending.value || updatePermission.isPending.value);

const code = ref("");
const description = ref("");
const module = ref("");
const sortOrder = ref<number | string>(0);
const methods = ref<Method[]>([]);
const submitted = ref(false);

const codeValid = computed(() => PERMISSION_CODE_PATTERN.test(code.value.trim()));

watch(
  () => props.open,
  (open) => {
    if (!open) return;
    code.value = props.permission?.name ?? "";
    description.value = props.permission?.description ?? "";
    module.value = props.permission?.module ?? "";
    sortOrder.value = props.permission?.sortOrder ?? 0;
    methods.value = props.permission ? methodsOf(props.permission) : ["VIEW", "CREATE", "UPDATE", "DELETE"];
    submitted.value = false;
  }
);

const toggle = (method: Method) => {
  methods.value = methods.value.includes(method)
    ? methods.value.filter((item) => item !== method)
    : METHODS.filter((item) => item === method || methods.value.includes(item));
};

const submit = async () => {
  submitted.value = true;
  if (!codeValid.value || methods.value.length === 0) return;
  const input = {
    name: code.value.trim(),
    description: description.value.trim() || null,
    module: module.value.trim() || null,
    sortOrder: Number(sortOrder.value) || 0,
    methods: [...methods.value],
  };
  try {
    if (props.permission) await updatePermission.mutateAsync({ id: props.permission.id, input });
    else await createPermission.mutateAsync(input);
  } catch {
    return; // the mutation already showed the failure toast
  }
  emit("update:open", false);
};
</script>
