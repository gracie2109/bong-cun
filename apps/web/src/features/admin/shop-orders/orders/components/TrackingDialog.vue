<template>
  <AppDialog
    v-model:open="open"
    :title="$t('shop.admin.dialogs.shipTitle')"
    :ok-text="$t('shop.admin.dialogs.shipOk')"
    :ok-disabled="!code.trim()"
    :busy="busy"
    @ok="$emit('submit')"
  >
    <div class="space-y-3">
      <p class="text-sm text-muted-foreground">{{ $t("shop.admin.dialogs.shipHint", { amount: money(cod) }) }}</p>
      <div class="space-y-1.5">
        <Label for="tracking-code">{{ $t("shop.admin.dialogs.tracking") }}</Label>
        <Input id="tracking-code" v-model="code" maxlength="40" autocomplete="off" />
      </div>
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { money } from "@/features/admin/pos/format";

const open = defineModel<boolean>("open", { required: true });
const code = defineModel<string>("code", { required: true });
defineProps<{ cod: number; busy: boolean }>();
defineEmits<{ submit: [] }>();
</script>
