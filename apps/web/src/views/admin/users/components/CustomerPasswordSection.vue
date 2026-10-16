<template>
  <section class="space-y-3 rounded-xl border bg-muted/30 p-4">
    <div class="flex items-center justify-between">
      <h3 class="flex items-center gap-2 text-sm font-semibold">
        <LockKeyhole class="size-4 text-primary" />
        {{ $t("pageFields.customers.form.passwordTitle") }}
      </h3>
      <button
        type="button"
        class="flex items-center gap-1 text-xs font-semibold text-primary hover:underline"
        @click="generate"
      >
        <RefreshCw class="size-3" />
        {{ $t("pageFields.customers.form.generate") }}
      </button>
    </div>
    <FormField v-slot="{ componentField }" name="password" :rules="passwordRule">
      <FormItem>
        <FormControl>
          <div class="relative">
            <Input
              v-bind="componentField"
              :type="showPassword ? 'text' : 'password'"
              class="pr-10 font-mono"
              :placeholder="$t('pageFields.customers.form.passwordPh')"
              autocomplete="new-password"
            />
            <button
              type="button"
              class="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground"
              @click="showPassword = !showPassword"
            >
              <EyeOff v-if="showPassword" class="size-4" />
              <Eye v-else class="size-4" />
            </button>
          </div>
        </FormControl>
        <FormMessage />
      </FormItem>
    </FormField>
    <div class="flex items-center gap-3">
      <div class="grid flex-1 grid-cols-4 gap-1">
        <span
          v-for="n in STRENGTH_LEVELS"
          :key="n"
          class="h-1.5 rounded-full"
          :class="n <= strength ? STRENGTH_COLORS[strength - 1] : 'bg-muted'"
        />
      </div>
      <span v-if="strength" class="text-xs font-medium text-muted-foreground">
        {{ $t(`pageFields.customers.form.strength.${STRENGTH_KEYS[strength - 1]}`) }}
      </span>
    </div>
    <p class="flex items-start gap-2 text-xs text-muted-foreground">
      <Info class="mt-0.5 size-3.5 shrink-0" />
      {{ $t("pageFields.customers.form.passwordHint") }}
    </p>
  </section>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import type { FormContext } from "vee-validate";
import { Eye, EyeOff, Info, LockKeyhole, RefreshCw } from "lucide-vue-next";
import { FormControl, FormField, FormItem, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import type { IUser } from "@/types/user.type";
import { generatePassword, passwordStrength, useCustomerRules } from "./customerFormRules";

const STRENGTH_LEVELS = [1, 2, 3, 4];
const STRENGTH_KEYS = ["weak", "medium", "strong", "veryStrong"];
const STRENGTH_COLORS = ["bg-red-500", "bg-amber-500", "bg-lime-500", "bg-green-500"];

const props = defineProps<{ form: FormContext<IUser> }>();

const { passwordRule } = useCustomerRules();
const showPassword = ref(false);
const strength = computed(() => passwordStrength(String(props.form.values.password ?? "")));

const generate = () => {
  props.form.setFieldValue("password", generatePassword());
  showPassword.value = true;
};
</script>
