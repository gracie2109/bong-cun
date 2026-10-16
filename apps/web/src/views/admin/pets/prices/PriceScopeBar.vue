<template>
  <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
    <div class="flex flex-wrap gap-1">
      <button
        v-for="item in species"
        :key="item.id"
        type="button"
        class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold transition-colors"
        :class="item.id === speciesId ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
        @click="speciesId = item.id"
      >
        <Icon v-if="item.icon" :icon="item.icon" class="size-4" />
        {{ item.name }}
      </button>
    </div>

    <div class="ml-auto flex flex-wrap items-center gap-3">
      <Select v-model="scope" :disabled="locked">
        <SelectTrigger class="w-56" :aria-label="$t('petCare.prices.scope')"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem :value="SHARED">{{ $t("petCare.prices.scopeShared") }}</SelectItem>
          <SelectItem v-for="branch in branches" :key="branch.id" :value="branch.id">
            {{ $t("petCare.prices.scopeBranch", { code: branch.code }) }}
          </SelectItem>
        </SelectContent>
      </Select>
      <label class="flex items-center gap-2 text-sm text-muted-foreground">
        <Switch v-model="onlyMissing" />
        {{ $t("petCare.prices.onlyMissing") }}
      </label>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Icon } from "@iconify/vue";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { SHARED } from "./usePriceCatalog";

defineProps<{
  species: { id: string; name: string; icon?: string | null }[];
  branches: { id: string; code: string }[];
  /** The scope cannot change while there are unsaved edits. */
  locked: boolean;
}>();

const speciesId = defineModel<string | undefined>("speciesId", { required: true });
const scope = defineModel<string>("scope", { required: true });
const onlyMissing = defineModel<boolean>("onlyMissing", { required: true });
</script>
