<template>
  <AppDialog
    v-model:open="open"
    :title="$t('petCare.pets.link.title')"
    :description="$t('petCare.pets.link.desc', { name: customer.fullName })"
    :ok-text="$t('petCare.pets.link.confirm')"
    :cancel-text="$t('petCare.common.cancel')"
    :ok-disabled="!link.selectedId.value"
    :busy="link.saving.value"
    @ok="link.submit"
  >
    <div class="space-y-3">
      <Input v-model="link.input.value" :placeholder="$t('petCare.pets.link.searchHint')" autocomplete="off" />
      <p v-if="link.searching.value" class="text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
      <p v-else-if="link.searched.value && link.results.value.length === 0" class="text-sm text-muted-foreground">
        {{ $t("petCare.pets.link.none") }}
      </p>
      <ul class="space-y-1">
        <li v-for="account in link.results.value" :key="account.userId">
          <button
            type="button"
            class="flex w-full flex-col rounded-lg border px-3 py-2 text-left text-sm hover:bg-muted/50"
            :class="link.selectedId.value === account.userId && 'border-primary bg-primary/5'"
            @click="link.selectedId.value = account.userId"
          >
            <span class="font-medium">{{ account.fullName || account.email }}</span>
            <span class="text-xs text-muted-foreground">{{ [account.email, account.phone].filter(Boolean).join(" · ") }}</span>
          </button>
        </li>
      </ul>
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import AppDialog from "@/components/common/AppDialog.vue";
import { Input } from "@/components/ui/input";
import type { Customer } from "@/repositories/customers";
import { useLinkAccount } from "./useLinkAccount";

const props = defineProps<{ customer: Customer }>();
const open = defineModel<boolean>("open", { required: true });

const link = useLinkAccount(
  () => props.customer.id,
  () => (open.value = false)
);
</script>
