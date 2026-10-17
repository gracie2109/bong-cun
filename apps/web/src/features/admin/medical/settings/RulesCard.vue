<template>
  <section class="rounded-xl border bg-white">
    <header class="flex items-center justify-between gap-3 border-b px-4 py-3">
      <div>
        <h2 class="font-semibold">{{ $t("medical.rules.title") }}</h2>
        <p class="text-xs text-muted-foreground">{{ $t("medical.rules.hint") }}</p>
      </div>
      <Button v-if="canEdit" size="sm" :disabled="!dirty || !valid || saving" @click="save">
        <Loader2 v-if="saving" class="mr-1 size-4 animate-spin" />
        {{ $t("petCare.common.save") }}
      </Button>
    </header>

    <div v-if="rules" class="grid gap-4 p-4 sm:grid-cols-2">
      <div class="space-y-1 sm:col-span-2">
        <Label>{{ $t("medical.rules.examService") }}</Label>
        <Select :model-value="rules.examServiceId ?? NO_EXAM" :disabled="!canEdit" @update:model-value="(value) => setExam(String(value))">
          <SelectTrigger :aria-label="$t('medical.rules.examService')"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem :value="NO_EXAM">{{ $t("medical.rules.noExam") }}</SelectItem>
            <SelectItem v-for="service in examServices" :key="service.id" :value="service.id">{{ service.name }}</SelectItem>
          </SelectContent>
        </Select>
        <p class="text-xs text-muted-foreground">
          {{ examServices.length ? $t("medical.rules.examServiceHint") : $t("medical.rules.noMedicalService") }}
        </p>
      </div>
      <div class="space-y-1">
        <Label for="rule-remind">{{ $t("medical.rules.remindAheadDays") }}</Label>
        <Input id="rule-remind" v-model.number="rules.remindAheadDays" type="number" min="0" max="90" step="1" :disabled="!canEdit" />
        <p class="text-xs text-muted-foreground">{{ $t("medical.rules.remindAheadDaysHint") }}</p>
      </div>
      <div class="space-y-1">
        <Label for="rule-contagious">{{ $t("medical.rules.contagiousDays") }}</Label>
        <Input id="rule-contagious" v-model.number="rules.contagiousDays" type="number" min="1" max="365" step="1" :disabled="!canEdit" />
        <p class="text-xs text-muted-foreground">{{ $t("medical.rules.contagiousDaysHint") }}</p>
      </div>
      <label class="flex items-start gap-2 text-sm sm:col-span-2">
        <Switch v-model="rules.requireVaccineForBoarding" :disabled="!canEdit" :aria-label="$t('medical.rules.requireVaccine')" />
        <span>
          <span class="block font-medium">{{ $t("medical.rules.requireVaccine") }}</span>
          <span class="block text-xs text-muted-foreground">{{ $t("medical.rules.requireVaccineHint") }}</span>
        </span>
      </label>
    </div>
    <p v-else-if="!loading" class="px-4 py-6 text-center text-sm text-muted-foreground">{{ $t("medical.rules.unavailable") }}</p>
    <p v-if="rules && !valid" class="px-4 pb-4 text-sm text-destructive">{{ $t("medical.errors.bad_rules") }}</p>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Loader2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { useAllPetServices } from "@/features/admin/pets/queries/petServices";
import { useRulesForm } from "./useRulesForm";

const NO_EXAM = "__none__";

const props = defineProps<{ branchId: string | undefined; canEdit: boolean }>();

const { rules, dirty, valid, save, saving, loading } = useRulesForm(computed(() => props.branchId));

const servicesQuery = useAllPetServices("medical");
const examServices = computed(() => servicesQuery.data.value ?? []);

const setExam = (value: string) => {
  if (!rules.value) return;
  const service = examServices.value.find((item) => item.id === value);
  rules.value.examServiceId = service?.id ?? null;
  rules.value.examServiceName = service?.name ?? null;
};
</script>
