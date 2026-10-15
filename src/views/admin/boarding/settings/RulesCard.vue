<template>
  <section class="rounded-xl border bg-white">
    <header class="flex items-center justify-between gap-3 border-b px-4 py-3">
      <div>
        <h2 class="font-semibold">{{ $t("boarding.rules.title") }}</h2>
        <p class="text-xs text-muted-foreground">{{ $t("boarding.rules.hint") }}</p>
      </div>
      <Button v-if="canEdit" size="sm" :disabled="!dirty || !valid || saving" @click="save">
        <Loader2 v-if="saving" class="mr-1 size-4 animate-spin" />
        {{ $t("petCare.common.save") }}
      </Button>
    </header>

    <div v-if="rules" class="grid gap-4 p-4 sm:grid-cols-2 xl:grid-cols-3">
      <div class="space-y-1">
        <Label for="rule-check-in">{{ $t("boarding.rules.checkInFrom") }}</Label>
        <Input id="rule-check-in" v-model="rules.checkInFrom" type="time" step="900" :disabled="!canEdit" />
        <p class="text-xs text-muted-foreground">{{ $t("boarding.rules.checkInFromHint") }}</p>
      </div>
      <div class="space-y-1">
        <Label for="rule-check-out">{{ $t("boarding.rules.checkOutBy") }}</Label>
        <Input id="rule-check-out" v-model="rules.checkOutBy" type="time" step="900" :disabled="!canEdit" />
        <p class="text-xs text-muted-foreground">{{ $t("boarding.rules.checkOutByHint") }}</p>
      </div>
      <div class="space-y-1">
        <Label for="rule-late-half">{{ $t("boarding.rules.lateHalfUntil") }}</Label>
        <Input id="rule-late-half" v-model="rules.lateHalfUntil" type="time" step="900" :disabled="!canEdit" />
        <p class="text-xs text-muted-foreground">{{ $t("boarding.rules.lateHalfUntilHint") }}</p>
      </div>
      <div class="space-y-1">
        <Label for="rule-max-nights">{{ $t("boarding.rules.maxNights") }}</Label>
        <Input id="rule-max-nights" v-model.number="rules.maxNights" type="number" min="1" max="365" step="1" :disabled="!canEdit" />
      </div>
      <div class="space-y-1">
        <Label>{{ $t("boarding.rules.dayStayNights") }}</Label>
        <Select :model-value="String(rules.dayStayNights)" :disabled="!canEdit" @update:model-value="(value) => (rules!.dayStayNights = Number(value))">
          <SelectTrigger :aria-label="$t('boarding.rules.dayStayNights')"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="item in DAY_STAY_OPTIONS" :key="item" :value="String(item)">{{ $t("boarding.rules.nights", { count: item }) }}</SelectItem>
          </SelectContent>
        </Select>
        <p class="text-xs text-muted-foreground">{{ $t("boarding.rules.dayStayNightsHint") }}</p>
      </div>
    </div>
    <p v-else-if="!loading" class="px-4 py-6 text-center text-sm text-muted-foreground">{{ $t("boarding.rules.unavailable") }}</p>
    <p v-if="rules && !valid" class="px-4 pb-4 text-sm text-destructive">{{ $t("boarding.errors.bad_rules") }}</p>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Loader2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { DAY_STAY_OPTIONS, useRulesForm } from "./useRulesForm";

const props = defineProps<{ branchId: string | undefined; canEdit: boolean }>();

const { rules, dirty, valid, save, saving, loading } = useRulesForm(computed(() => props.branchId));
</script>
