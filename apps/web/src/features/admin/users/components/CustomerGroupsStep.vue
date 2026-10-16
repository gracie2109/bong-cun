<template>
  <div class="space-y-4">
    <div>
      <h3 class="font-semibold">{{ $t("pageFields.customers.form.groupsTitle") }}</h3>
      <p class="text-sm text-muted-foreground">{{ $t("pageFields.customers.form.groupsDesc") }}</p>
    </div>
    <CustomCombobox
      :options="options"
      :value="selectedIds"
      :placeholder="$t('pageFields.customers.form.groupsPlaceholder')"
      is-multi
      search-label
      show-clear
      @select-option="onChange"
    />
    <p
      v-if="!groupOptions.length"
      class="rounded-lg border border-dashed p-4 text-center text-sm text-muted-foreground"
    >
      {{ $t("pageFields.customers.form.groupsEmpty") }}
    </p>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { FormContext } from "vee-validate";
import type { IUser } from "@bongcun/core/users";
import { CustomCombobox } from "@/components/common";
import { pickGroups, toGroupOptions } from "./customerGroupOptions";

const props = defineProps<{ form: FormContext<IUser>; groupOptions: any[] }>();

const options = computed(() => toGroupOptions(props.groupOptions));
const selectedIds = computed<string[]>(() => props.form.values.groupIds ?? []);

const onChange = (ids: string[]) => {
  props.form.setFieldValue("groupIds", ids.length ? ids : null);
  props.form.setFieldValue("groupProfile", pickGroups(props.groupOptions, ids));
};
</script>
