<template>
  <div class="space-y-4">
    <div>
      <h3 class="font-semibold">{{ $t("pageFields.customers.form.groupsTitle") }}</h3>
      <p class="text-sm text-muted-foreground">{{ $t("pageFields.customers.form.groupsDesc") }}</p>
    </div>
    <Multiselect
      v-model="groups"
      :options="groupOptions"
      :multiple="true"
      :close-on-select="false"
      :clear-on-select="false"
      :preserve-search="true"
      :placeholder="$t('pageFields.customers.form.groupsPlaceholder')"
      label="name"
      track-by="name"
      @update:model-value="onChange"
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
import { ref } from "vue";
import type { FormContext } from "vee-validate";
import Multiselect from "vue-multiselect";
import type { IUser } from "@/types/user.type";

const props = defineProps<{ form: FormContext<IUser>; groupOptions: any[] }>();

const groups = ref([]);

const onChange = (value: any[] | null) => {
  props.form.setFieldValue("groupIds", value?.map((i) => i.id) ?? null);
  props.form.setFieldValue("groupProfile", value ?? []);
};
</script>
